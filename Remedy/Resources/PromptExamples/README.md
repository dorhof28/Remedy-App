# Prompt examples

Made-up surgery papers with the right answers. No real patient data.

- The AI gets up to 3 of these in its prompt as worked examples (the phone model gets 1). Doctor-checked ones go first, then ones for the same kind of paper.
- RemedyTests/PromptExampleTests runs our own code on every example: stop days, surgery date and hidden names.
- Most examples have no surgery date printed, only days like "7 days before surgery". The AI stores days from surgery and the patient types the date in. Two of the HSS examples keep a printed date so that case is covered too.
- Three examples (`example-hss-...`) come from the fictitious HSS sample papers.
- To add one, copy a file, give it a new `example-...` name, and fill in `pageText`, `answer` and `checks`. Put the reviewer's name in `checkedBy` once a doctor has checked it.

The more real-world layouts we add, the better the answers get, with no retraining.
