# Wake-word keyword tokenization

`assets/wake_words/kws/keywords.txt` contains BPE-tokenized keyword phrases
for the `sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01` model.

## Current phrases (`keywords_raw.txt` equivalent)

```
SAMO LEVSKI
TRAINER
THOMAS
```

One phrase per line, order must match `WakeWordPreset` enum order:
`samoLevski` (line 0), `trainer` (line 1), `thomas` (line 2).

## Regenerating after a phrase change

Requires the model's `bpe.model` (committed here as `tool/wake_words/bpe.model`)
and the Python `sherpa-onnx` package:

```bash
pip install sherpa-onnx

# keywords_raw.txt: plain text, one phrase per line, upper-case
sherpa-onnx-cli text2token \
  --tokens assets/wake_words/kws/tokens.txt \
  --tokens-type bpe \
  --bpe-model tool/wake_words/bpe.model \
  keywords_raw.txt \
  assets/wake_words/kws/keywords.txt
```

Commit the updated `keywords.txt`. Do **not** add `bpe.model` to
`flutter: assets:` — it is only used offline.

## Manual tokenization reference (GigaSpeech BPE)

Derived by greedy longest-match from `tokens.txt`:

| Phrase      | Tokenized                   |
|-------------|-----------------------------|
| SAMO LEVSKI | `▁SA MO ▁LE V S K I`        |
| TRAINER     | `▁TRA IN ER`                 |
| THOMAS      | `▁TH OM AS`                  |

Per-phrase boost/threshold suffixes (`:<boost>` / `#<threshold>`) can be
appended for tuning, e.g. `▁SA MO ▁LE V S K I :2.0 #0.20`.
Record final tuned values in the PR description after device verification.
