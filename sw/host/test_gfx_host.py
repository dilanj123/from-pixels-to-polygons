import io
import struct
import tempfile
import unittest
from pathlib import Path

import gfx_host


class HostProtocolTests(unittest.TestCase):
    def test_word_byte_order_and_command(self):
        words = gfx_host.command_begin_frame(0x1234, 0xA5)
        self.assertEqual(words, [0x10001234, 0xA5])
        self.assertEqual(gfx_host.words_to_bytes(words), bytes.fromhex("34120010 a5000000"))

    def test_response_packet_lengths(self):
        values = [0xA0005678, 0x12, 0x24]
        stream = io.BytesIO(gfx_host.words_to_bytes(values))
        self.assertEqual(gfx_host.read_packet(stream), values)

    def test_readback_reconstruction_and_checksum(self):
        data_words = [0x04030201] * 19200
        checksum = sum(data_words) & 0xFFFFFFFF
        descriptor = (1 << 21) | (240 << 10) | 320
        packet = [0xC0001234, 19200, descriptor, *data_words,
                  0xD0001234, 0, checksum]
        class FullDuplexMemory(io.BytesIO):
            def write(self, value):
                return len(value)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "front.rgb332"
            port = FullDuplexMemory(gfx_host.words_to_bytes(packet))
            received = gfx_host.fetch_readback(port, 0x1234, output)
            self.assertEqual(len(received), 19206)
            self.assertEqual(received[19205], checksum)
            self.assertEqual(output.read_bytes(), bytes((1, 2, 3, 4)) * 19200)

    def test_draw_payload_length(self):
        with self.assertRaises(ValueError):
            gfx_host.command_draw_triangle(1, [0] * 14)


if __name__ == "__main__":
    unittest.main()
