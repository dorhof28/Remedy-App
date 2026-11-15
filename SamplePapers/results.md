# model comparison

A report, not a pass or fail. Sample papers only.

## how to run

1. `swift SamplePapers/make-pdfs.swift` if `SamplePapers/pdfs/` is missing
2. set `TEST_RUNNER_REMEDY_COMPARE=1` and any keys as `TEST_RUNNER_REMEDY_KEY_<CLAUDE|GEMINI|OPENAI|OPENROUTER|GROQ|MISTRAL>`
3. `TEST_RUNNER_REMEDY_COMPARE=1 TEST_RUNNER_REMEDY_KEY_CLAUDE=... scripts/check.sh test ModelComparisonTests`

Readers without a key say "no key". On this iPhone and Apple Private Cloud say "unavailable" on a Simulator without Apple Intelligence.
Each paper is drawn to pixels, read by Vision, hidden with the real redaction, then planned by the reader.
Medicines right = name found with the right action. Stop days right = start and end day match. Doses right = strength matches.

| reader | medicines right | stop days right | doses right | seconds per paper |
|---|---|---|---|---|
| On this iPhone | 21/31 | 16/18 | 12/13 | 16.3 |
| Apple Private Cloud | unavailable | | | |
| Claude | no key | | | |
| Google Gemini | no key | | | |
| OpenAI | no key | | | |
| OpenRouter | no key | | | |
| Groq | no key | | | |
| Mistral | no key | | | |