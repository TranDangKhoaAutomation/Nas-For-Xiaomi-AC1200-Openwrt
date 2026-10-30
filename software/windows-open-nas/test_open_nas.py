import unittest
from open_nas import parse_link


class LinkValidation(unittest.TestCase):
    def test_valid_share_roots(self):
        self.assertEqual(parse_link('khoanas://open?host=100.114.53.95&share=BITLOCKER'),
                         ('100.114.53.95', r'\\100.114.53.95\BITLOCKER'))
        self.assertEqual(parse_link('khoanas://open?host=192.168.1.1&share=My%20Data')[1],
                         r'\\192.168.1.1\My Data')

    def test_refuses_public_hosts_and_non_share_payloads(self):
        for link in (
            'khoanas://open?host=8.8.8.8&share=data',
            'khoanas://open?host=evil.example&share=data',
            'khoanas://open?host=192.168.1.1&share=data%5Cfile.exe',
            'khoanas://open?host=192.168.1.1&share=..',
            'khoanas://open?host=192.168.1.1&share=data%22%20%26%20calc',
            'khoanas://open?host=192.168.1.1&share=data&command=calc',
            'khoanas://open?host=192.168.1.1&host=10.0.0.1&share=data',
            'khoanas://open/run?host=192.168.1.1&share=data',
            'file://192.168.1.1/data',
            'khoanas://open?host=192.168.1.1&share=data%00',
        ):
            with self.subTest(link=link), self.assertRaises(ValueError):
                parse_link(link)


if __name__ == '__main__':
    unittest.main()
