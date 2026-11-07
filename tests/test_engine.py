import json
from pathlib import Path
import subprocess
import sys
import unittest
import tempfile
import wave
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from engine import clean, transcribe, rewrite


class CleanupTests(unittest.TestCase):
    def test_bilingual_fillers_without_removing_meaningful_words(self):
        self.assertEqual(clean('Um, the number is 42. 嗯，我们周五见。'), 'the number is 42. 我们周五见。')
        self.assertEqual(clean('human umbrella 然后那么重要'), 'human umbrella 然后那么重要')

    def test_missing_model_is_actionable_json_error(self):
        result = subprocess.run([sys.executable, 'engine.py', '--audio', 'missing.wav', '--model', '/nonexistent/local-flow-model'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('model is missing', json.loads(result.stdout)['error'])

    def test_missing_rewriter_keeps_the_transcript(self):
        result = subprocess.run([sys.executable, 'engine.py', '--text', 'Um, keep 42.', '--mode', 'rewrite', '--rewrite-model', '/nonexistent/model'], capture_output=True, text=True, check=True)
        output = json.loads(result.stdout)
        self.assertEqual(output['text'], 'keep 42.')
        self.assertIn('basic cleanup retained', output['warning'])

    def test_silence_never_invokes_whisper(self):
        with tempfile.TemporaryDirectory() as directory:
            model = Path(directory) / 'model.bin'
            model.touch()
            audio = Path(directory) / 'silence.wav'
            with wave.open(str(audio), 'wb') as recording:
                recording.setnchannels(1)
                recording.setsampwidth(2)
                recording.setframerate(16000)
                recording.writeframes(b'\0\0' * 16000)
            with patch('engine.run', side_effect=AssertionError('Whisper must not run on silence')):
                self.assertEqual(transcribe(audio, model, 'auto', '/not-used'), '')

    def test_rewriter_rejects_language_loss(self):
        with tempfile.NamedTemporaryFile() as model:
            with patch('engine.run', return_value='Send the report. We meet tomorrow.'):
                with self.assertRaisesRegex(RuntimeError, 'source language'):
                    rewrite('Send the report. 我们明天见。', model.name, '/not-used')

    def test_sentence_grouping_preserves_decimal_numbers(self):
        with patch('engine.rewrite_segment', side_effect=lambda text, *_: text):
            self.assertEqual(rewrite('It costs 9.30 dollars. 明天见。', '', ''), 'It costs 9.30 dollars. 明天见。')


if __name__ == '__main__':
    unittest.main()
