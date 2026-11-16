# Validation on real data

Counts below were produced by running the tool on public data, not on the synthetic samples in `examples/`.

## Validation
- The LEI check is the ISO 17442 / ISO 7064 mod 97-10 algorithm. It was confirmed against a real LEI (`HWUPKR0MPOU8FGXBT394`).
- Three of the five LEIs used in the first version of the examples failed the checksum. They were replaced with valid ones, and DOR003 now rejects wrong check digits.
- Implementing Regulation (EU) 2024/2956 allows an EUID for providers without an LEI, so a well-formed EUID is accepted.

## Limits
The tool checks format and checksum. It cannot confirm that an LEI is active in the GLEIF database.
