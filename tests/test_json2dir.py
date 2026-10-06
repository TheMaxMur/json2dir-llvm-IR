#!/usr/bin/env python3
"""Black-box filesystem tests; optional differential tests against Rust json2dir."""
import argparse
import json
import os
from pathlib import Path
import random
import stat
import subprocess
import tempfile
import unittest

ARGS = None


def snapshot(root):
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = Path(directory) / name
            relative = str(path.relative_to(root))
            mode = stat.S_IMODE(path.lstat().st_mode)
            if path.is_symlink():
                result[relative] = ('link', os.readlink(path))
            elif path.is_dir():
                result[relative] = ('dir', mode)
            else:
                try:
                    content = path.read_bytes()
                except PermissionError:
                    content = None
                result[relative] = ('file', mode, content)
    return result


def run(binary, data, setup=None, args=(), mask=0o022):
    if isinstance(data, str):
        data = data.encode('utf-8')
    with tempfile.TemporaryDirectory(prefix='json2dir-test-') as directory:
        root = Path(directory)
        if setup:
            setup(root)
        process = subprocess.run(
            [binary, *args], input=data, cwd=root, capture_output=True,
            umask=mask, timeout=15,
        )
        return process, snapshot(root)


class Json2DirTests(unittest.TestCase):
    def invoke(self, data, setup=None, args=(), mask=0o022):
        process, tree = run(ARGS.binary, data, setup, args, mask)
        self.assertIn(process.returncode, (0, 1), process.stderr)
        self.assertEqual(process.stdout, b'')
        if process.returncode:
            self.assertTrue(process.stderr, 'errors must have a diagnostic')
        else:
            self.assertEqual(process.stderr, b'')
        self.assertNotIn(b'AddressSanitizer', process.stderr)
        return process, tree

    def test_example(self):
        data = (Path(__file__).resolve().parent.parent / 'example-tree.json').read_bytes()
        p, tree = self.invoke(data)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree, {
            'greeting': ('file', 0o644, b'Hello, world!'),
            'dir': ('dir', 0o755),
            'dir/subfile': ('file', 0o644, b'Content.\n'),
            'dir/subdir': ('dir', 0o755),
            'symlink': ('link', 'target path'),
            'script': ('file', 0o755, b'#!/bin/sh\necho Howdy!'),
        })

    def test_empty_and_whitespace(self):
        for data in ('{}', ' \t\r\n{}\r\n'):
            with self.subTest(data=data):
                p, tree = self.invoke(data)
                self.assertEqual(p.returncode, 0)
                self.assertEqual(tree, {})

    def test_usage(self):
        for args in (('--help',), ('--version',), ('file.json',), ('a', 'b')):
            p, tree = self.invoke('{}', args=args)
            self.assertEqual(p.returncode, 1)
            self.assertIn(b'Usage: json2dir', p.stderr)
            self.assertEqual(tree, {})

    def test_top_level(self):
        for data in ('3', 'null', 'true', 'false', '[]', '"foo"', '-3.12e-2'):
            with self.subTest(data=data):
                p, tree = self.invoke(data)
                self.assertEqual(p.returncode, 1)
                self.assertIn(b'expected provided JSON to be an object', p.stderr)
                self.assertEqual(tree, {})

    def test_invalid_json_never_writes(self):
        cases = [
            '', 'f', '{} {}', '{"a":"ok"} garbage', '{"a":"ok",}',
            '{"a":"ok","z":}', '{"a":"ok","z":"\\q"}',
            '{"a":"ok","z":[1,]}', '{a:"x"}', '{"a" "x"}',
            '{"a":"x"', '{"a":"unterminated}', '{"a":"raw\nnewline"}',
            '{"a":01}', '{"a":-}', '{"a":1.}', '{"a":1e}',
            '{"a":+1}', '{"a":NaN}', '{"a":Infinity}', '{"a":1e400}',
            '{"a":.1}', '{"a":--1}', '{"a":trueX}', '{"a":falseX}',
            '{"a":nul}', '{"a":1e+}', '{"a":0x10}', '{}\0',
            '{"a":"\\u000"}', '{"a":"\\uXX00"}',
            '{"a":"\\uD800"}', '{"a":"\\uDC00"}',
            '{"a":"\\uD800\\u0041"}', '{"a":"\\uD800\\uD800"}',
            '{"a":"\\uD800x"}', '{"a":"\\uD800\\n"}',
            '\ufeff{}',
        ]
        for data in cases:
            with self.subTest(data=data):
                p, tree = self.invoke(data)
                self.assertEqual(p.returncode, 1)
                self.assertIn(b"couldn't convert stdin to JSON", p.stderr)
                self.assertEqual(tree, {})

    def test_invalid_utf8(self):
        sequences = [b'\xff', b'\xc0\xaf', b'\x80', b'\xc2', b'\xe0\x80\x80',
                     b'\xed\xa0\x80', b'\xf0\x80\x80\x80', b'\xf4\x90\x80\x80',
                     b'\xf5\x80\x80\x80', b'\xe2\x28\xa1', b'\xf0\x9f\x98']
        for value in sequences:
            with self.subTest(value=value):
                p, tree = self.invoke(b'{"a":"ok","z":"' + value + b'"}')
                self.assertEqual(p.returncode, 1)
                self.assertIn(b'UTF-8', p.stderr)
                self.assertEqual(tree, {})

    def test_unicode_and_escapes(self):
        data = r'{"\u043f\u0440\u0438\u0432\u0435\u0442":"\"\\\/\b\f\n\r\t\u0000\u007F\u0080\u07FF\u0800\uD7FF\uE000\uFFFF\uD800\uDC00\uDBFF\uDFFF\uD83D\uDE00"}'
        p, tree = self.invoke(data)
        self.assertEqual(p.returncode, 0)
        value = json.loads(data)['привет'].encode()
        self.assertEqual(tree, {'привет': ('file', 0o644, value)})
        data = json.dumps({'русский 🐈': '日本語 😀'}, ensure_ascii=False)
        p, tree = self.invoke(data)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree['русский 🐈'][2], '日本語 😀'.encode())

    def test_empty_files(self):
        p, tree = self.invoke('{"f":"","s":["script",""]}')
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree, {'f': ('file', 0o644, b''), 's': ('file', 0o755, b'')})

    def test_nul_in_contents(self):
        p, tree = self.invoke(r'{"f":"a\u0000b","s":["script","\u0000"]}')
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree['f'][2], b'a\0b')
        self.assertEqual(tree['s'][2], b'\0')

    def test_nul_in_paths(self):
        for data in (r'{"x\u0000y":"text"}', r'{"link":["link","x\u0000y"]}'):
            p, tree = self.invoke(data)
            self.assertEqual(p.returncode, 1)
            self.assertEqual(tree, {})

    def test_path_validation(self):
        for key in ('', '.', '..', '/', '/foo', './foo', 'foo/bar', 'foo/../bar',
                    'foo/..', 'foo//bar', '../foo', './', '//'):
            with self.subTest(key=key):
                p, tree = self.invoke(json.dumps({key: 'no'}))
                self.assertEqual(p.returncode, 1)
                self.assertEqual(tree, {})
        p, tree = self.invoke(json.dumps({'back\\slash': 'ok', '..normal': 'ok'}))
        self.assertEqual(p.returncode, 0)
        self.assertEqual(len(tree), 2)

    def test_trailing_slashes_and_dots(self):
        for key in ('foo/', 'foo//', 'foo/.', 'foo/./', 'foo//./'):
            with self.subTest(key=key):
                p, tree = self.invoke(json.dumps({key: 'text'}))
                self.assertEqual(p.returncode, 1)
                self.assertEqual(tree, {})
                p, tree = self.invoke(json.dumps({key: {'f': 'text'}}))
                self.assertEqual(p.returncode, 1 if '.' in key else 0)
                if '.' in key:
                    self.assertEqual(tree, {})
                p, tree = self.invoke(json.dumps({key: {'f': 'text'}}),
                                      lambda root: (root / 'foo').mkdir())
                self.assertEqual(p.returncode, 0)
                self.assertEqual(tree['foo/f'][2], b'text')

    def test_invalid_values(self):
        for value in (None, True, False, 0, -1, 1.25):
            p, tree = self.invoke(json.dumps({'f': value}))
            self.assertEqual(p.returncode, 1)
            self.assertIn(b'expected a JSON value', p.stderr)
            self.assertEqual(tree, {})

    def test_array_shapes(self):
        for array in ([], ['link'], ['script'], [1, 2], ['link', 2],
                      [True, 'x'], ['link', 'x', 'extra'], [['link'], 'x']):
            p, tree = self.invoke(json.dumps({'f': array}))
            self.assertEqual(p.returncode, 1)
            self.assertIn(b'form [type, payload]', p.stderr)
            self.assertEqual(tree, {})
        for kind in ('', 'Link', 'scripts', 'linksym', 'link\0', 'script\0'):
            p, tree = self.invoke(json.dumps({'f': [kind, 'x']}))
            self.assertEqual(p.returncode, 1)
            self.assertIn(b'either "link" or "script"', p.stderr)
            self.assertEqual(tree, {})

    def test_duplicate_last_wins(self):
        cases = [
            '{"f":"old","f":"new"}',
            '{"f":false,"f":"new"}',
            '{"f":{"nested":"old"},"f":"new"}',
            r'{"f":"old","\u0066":"new"}',
            '{"f":"one","f":"two","f":"new"}',
        ]
        for data in cases:
            p, tree = self.invoke(data)
            self.assertEqual(p.returncode, 0)
            self.assertEqual(tree, {'f': ('file', 0o644, b'new')})

    def test_sorted_application(self):
        p, tree = self.invoke('{"z":"later","m":false,"a":"first"}')
        self.assertEqual(p.returncode, 1)
        self.assertEqual(tree, {'a': ('file', 0o644, b'first')})

    def test_sorted_unicode_keys(self):
        p, tree = self.invoke('{"я":"later","é":false,"a":"first"}')
        self.assertEqual(p.returncode, 1)
        self.assertEqual(tree, {'a': ('file', 0o644, b'first')})

    def test_overwrite_and_preserve_unrelated_entries(self):
        def setup(root):
            (root / 'dir').mkdir()
            (root / 'dir' / 'keep').write_bytes(b'keep')
            (root / 'f').write_bytes(b'old')
            (root / 'outside').write_bytes(b'untouched')
            (root / 'link').symlink_to('outside')
        p, tree = self.invoke('{"dir":{"new":"new"},"f":"new","link":"new"}', setup)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree['dir/keep'][2], b'keep')
        self.assertEqual(tree['dir/new'][2], b'new')
        self.assertEqual(tree['f'][2], b'new')
        self.assertEqual(tree['link'], ('file', 0o644, b'new'))
        self.assertEqual(tree['outside'][2], b'untouched')

    def test_symlink_replacement_with_directory(self):
        def setup(root):
            (root / 'target').mkdir()
            (root / 'target' / 'keep').write_text('keep')
            (root / 'dir').symlink_to('target', target_is_directory=True)
        p, tree = self.invoke('{"dir":{"f":"new"}}', setup)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree['dir'], ('dir', 0o755))
        self.assertEqual(tree['dir/f'][2], b'new')
        self.assertEqual(tree['target/keep'][2], b'keep')
        self.assertNotIn('target/f', tree)

    def test_overwrite_file_with_directory(self):
        p, tree = self.invoke('{"f":{"nested":"new"}}', lambda root: (root / 'f').write_text('old'))
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree['f/nested'][2], b'new')

    def test_directory_is_not_removed_for_file_or_link(self):
        def setup(root):
            (root / 'f').mkdir()
            (root / 'f' / 'keep').write_text('keep')
        for data in ('{"f":"text"}', '{"f":["script","text"]}', '{"f":["link","x"]}'):
            p, tree = self.invoke(data, setup)
            self.assertEqual(p.returncode, 1)
            self.assertEqual(tree['f/keep'][2], b'keep')

    def test_invalid_value_unlinks_existing_file(self):
        p, tree = self.invoke('{"f":false}', lambda root: (root / 'f').write_text('old'))
        self.assertEqual(p.returncode, 1)
        self.assertEqual(tree, {})

    def test_script_umask(self):
        for mask in (0, 0o022, 0o077, 0o777):
            p, tree = self.invoke('{"f":"data","s":["script","data"]}', mask=mask)
            self.assertEqual(p.returncode, 0)
            self.assertEqual(tree['f'][1], 0o666 & ~mask)
            self.assertEqual(tree['s'][1], (0o666 & ~mask) | 0o111)

    def test_nesting_limit(self):
        for count, status in ((127, 0), (128, 1), (3000, 1)):
            data = '{"a":' * count + '"end"' + '}' * count
            p, tree = self.invoke(data)
            self.assertEqual(p.returncode, status)
            if status:
                self.assertEqual(tree, {})

    def test_large_string_crosses_read_chunks(self):
        value = 'Abc😀\n\0' * 30000
        p, tree = self.invoke(json.dumps({'f': value}))
        self.assertEqual(p.returncode, 0)
        self.assertEqual(tree['f'][2], value.encode())

    def test_many_reverse_order_keys(self):
        data = {f'f{n:05}': str(n) for n in range(2000, -1, -1)}
        p, tree = self.invoke(json.dumps(data))
        self.assertEqual(p.returncode, 0)
        self.assertEqual(len(tree), len(data))
        for name, value in data.items():
            self.assertEqual(tree[name][2], value.encode())

    def test_read_error(self):
        with tempfile.TemporaryDirectory() as directory:
            # Reading a directory as stdin raises EISDIR on both supported OSes.
            fd = os.open(directory, os.O_RDONLY)
            try:
                p = subprocess.run([ARGS.binary], stdin=fd, cwd=directory, capture_output=True)
            finally:
                os.close(fd)
            self.assertEqual(p.returncode, 1)
            self.assertIn(b"couldn't read stdin", p.stderr)

    def test_closed_stderr(self):
        with tempfile.TemporaryDirectory() as directory:
            for data, status, args in ((b'{}', 0, ()), (b'x', 1, ()), (b'{}', 1, ('--help',))):
                p = subprocess.run([ARGS.binary, *args], input=data, cwd=directory,
                                   stdout=subprocess.PIPE, preexec_fn=lambda: os.close(2))
                self.assertEqual(p.returncode, status)

    @unittest.skipIf(os.geteuid() == 0, 'permission errors require an unprivileged user')
    def test_directory_permission_error(self):
        def setup(root):
            (root / 'f').mkdir(mode=0o600)
        p, tree = self.invoke('{"f":{}}', setup)
        self.assertEqual(p.returncode, 1)
        self.assertIn(b'set the current dir', p.stderr)


class DifferentialTests(unittest.TestCase):
    def test_reference(self):
        if not ARGS.reference:
            self.skipTest('pass --reference to compare against the original binary')
        rng = random.Random(20261006)
        cases = [
            b'{}', b'{"f":"old","f":"new"}', b'{"z":"later","a":false}',
            b'{"f":false,"f":"new"}', b'{"f":"x","f":null}',
            b'{"f":"\\uD83D\\uDE00"}', b'{"f":"\\u0000"}',
            b'{"f":"\\uD800"}', b'{"f":"\\uDC00"}', b'{"f":"\xff"}',
        ]
        keys = ['', '.', '..', '/', '/foo', '//', './foo', 'foo', 'foo/', 'foo//',
                'foo/.', 'foo/./', 'foo/bar', 'foo/../bar', 'back\\slash', 'русский',
                '😀', 'foo\0bar', ' ', '\n', 'foo/..', '/./', '../.']
        values = ['', 'text', {}, {'nested': 'x'}, ['link', 'target'], ['script', 'x'],
                  [], ['link'], ['LINK', 'x'], ['link', None], False, None, 1, -1, 1.5]
        for key in keys:
            for value in values:
                cases.append(json.dumps({key: value}, ensure_ascii=False).encode())
        for number in ('0', '-0', '1e-999', '1e400', '-1e400', '01', '1.', '1e+',
                       '9' * 500, '0.' + '0' * 500 + '1', '1e' + '9' * 100):
            cases.append(('{"f":' + number + '}').encode())
        for count in (126, 127, 128, 1000):
            cases.append(('{"f":' * count + '"end"' + '}' * count).encode())

        def value(depth=0):
            options = ['text', '', 'русский 😀\n\0', ['link', '../target'],
                       ['script', '#!/bin/sh\necho ok\n'], None, False, 2, [], ['bad', 'x']]
            if depth < 3:
                options.append({f'd{n}': value(depth + 1) for n in range(rng.randrange(4))})
            return rng.choice(options)

        for _ in range(200):
            data = {rng.choice(['a', 'b', 'c', 'dir', '😀', '.', 'bad/name']): value()
                    for _ in range(rng.randrange(8))}
            encoded = json.dumps(data, ensure_ascii=rng.choice([True, False])).encode()
            cases.append(encoded)
        # Mutate otherwise valid JSON, covering strings, delimiters and EOF.
        baseline = b'{"a":"\\uD83D\\uDE00","b":{"c":"hello"},"d":["script","echo hi"]}'
        for _ in range(250):
            data = bytearray(baseline)
            for _ in range(rng.randrange(1, 4)):
                index = rng.randrange(len(data))
                if rng.randrange(2):
                    data[index] = rng.randrange(256)
                else:
                    del data[index]
            cases.append(bytes(data))

        def files(root):
            (root / 'foo').write_text('old')
            (root / 'a').write_text('old')
            (root / 'dir').mkdir()
            (root / 'dir' / 'keep').write_text('keep')

        def links(root):
            (root / 'target').mkdir()
            (root / 'target' / 'keep').write_text('keep')
            (root / 'foo').symlink_to('target', target_is_directory=True)
            (root / 'a').symlink_to('missing')

        count = 0
        for setup in (None, files, links):
            for data in cases:
                left, left_tree = run(ARGS.binary, data, setup)
                right, right_tree = run(ARGS.reference, data, setup)
                self.assertEqual(left.returncode, right.returncode,
                                 (data, left.stderr, right.stderr))
                self.assertEqual(left_tree, right_tree, (data, left.stderr, right.stderr))
                self.assertEqual(left.stdout, right.stdout)
                count += 1
        print(f'Compared {count} inputs/environments against the reference binary.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', default='./json2dir')
    parser.add_argument('--reference')
    ARGS, rest = parser.parse_known_args()
    ARGS.binary = str(Path(ARGS.binary).resolve())
    if ARGS.reference:
        ARGS.reference = str(Path(ARGS.reference).resolve())
    unittest.main(argv=[__file__, *rest], verbosity=2)
