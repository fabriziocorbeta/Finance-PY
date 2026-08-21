# Receipt/Factura Photo Import — Design Spec

**Date:** 2026-07-28
**Project:** FinancePY (repo `cd-co-erp`, branch `main`)
**Status:** Approved, ready for implementation plan

## Purpose

Let a photographed receipt/factura (jpg/png) go through the same "Importar documento" flow already used for bank statement PDFs, and come out the other end as a real (pending, user-reviewable) transaction — instead of silently landing in the dead vector-store upload path it hits today.

## Current state (confirmed by reading the code, not assumed)

- `ImportsController#create_document_import` only routes `.pdf` files to `create_pdf_import` (the path that leads to AI classification + transaction extraction). Any other extension — including `.jpg`/`.png` — goes to the generic `VectorStore` upload branch, which is dead code against the NVIDIA NIM provider (`/v1/vector_stores` returns 404, confirmed in the 2026-07-25/27 session).
- `Provider::Openai::PdfProcessor#process` tries `PDF::Reader` text extraction first, then falls back to `process_with_vision`, which calls `convert_pdf_to_images` — this unconditionally shells out to `pdftoppm` assuming the input is a real PDF. It cannot accept a raw JPEG/PNG as-is today.
- `Import::DOCUMENT_TYPES` has no type specific to a single-purchase receipt; the closest, `financial_document`, is a catch-all (tax forms, receipts, invoices, reports) and is explicitly excluded from `ProcessPdfJob#statement_with_transactions?`, so it never generates import rows today — it only gets a summary.

## Non-goals

- No multi-item line-by-line extraction. A factura here means "one purchase, one transaction" (merchant + date + total) — not itemized line splitting. If itemized splitting is ever wanted, that's a separate future spec.
- No change to the existing bank-statement PDF path (`BankStatementExtractor` stays untouched; this is a new, smaller extractor for a fundamentally different shape of input — one photo, one transaction, vs. one multi-page statement, many transactions).
- No OCR library added — reuses the existing vision-model call path (already in production for scanned PDFs).

## Architecture

```
User uploads .jpg/.png via existing "Importar documento" screen
  -> ImportsController#create_document_import (extended: recognizes image extensions)
       -> create_pdf_import(file)  [existing method, unchanged — PdfImport + process_with_ai_later]
            -> ProcessPdfJob (existing job, two small extensions)
                 -> PdfImport#process_with_ai
                      -> Provider::Openai#analyze_pdf
                           -> PdfProcessor.process (extended: skips PDF::Reader + pdftoppm
                                                     for image content-types, sends the raw
                                                     image straight to the vision model)
                 -> if document_type == "receipt": PdfImport#extract_transactions
                                                     (new: Provider::Openai::ReceiptExtractor,
                                                      not BankStatementExtractor)
```

### Controller change

`ImportsController#create_document_import`: extend the extension check so `.jpg`/`.jpeg`/`.png` route to `create_pdf_import(file)` the same way `.pdf` does today (same size-limit check, same `PdfImport` model — the attachment is still called `pdf_file` on the model; that name doesn't change, it just also holds an image now, matching how `pdf_file_content` is already a generic byte-reader).

### `PdfProcessor` change

Needs to know the content type of what it's processing (currently assumes PDF unconditionally):
- New `content_type:` param (`imp.pdf_file.content_type`, e.g. `image/jpeg`).
- If `content_type` starts with `image/`: skip `process_with_text_extraction` entirely (no PDF::Reader on a JPEG) and skip `convert_pdf_to_images`'s `pdftoppm` call — instead base64-encode `pdf_content` directly and build the vision message with the real `content_type` in the data URL (today's code hardcodes `data:image/png;base64,` regardless of source format, which happens to still work since pdftoppm always outputs PNG — but a real photo won't be PNG, so the mime type must be threaded through correctly here).
- Classification instructions gain a new document type: `receipt` — "A single purchase receipt or factura: one merchant, one date, one total amount. Distinct from `financial_document`, which is for multi-page or non-transactional financial paperwork (tax forms, contracts, statements you'd classify separately)."

### `ProcessPdfJob` change

- `statement_with_transactions?` becomes `document_type.in?(%w[bank_statement credit_card_statement receipt])` — a `receipt` classification now also triggers `pdf_import.extract_transactions` and row generation, ending in the same `pending` status (user reviews/publishes the row) as a bank statement import.

### New extractor: `app/models/provider/openai/receipt_extractor.rb`

Deliberately not `BankStatementExtractor` — no chunking, no multi-page loop, no per-chunk retry-on-empty-array logic (all of that exists to handle a 4-page statement with 45 rows; a receipt is one call, one expected transaction). Structure:
- Single vision-model call (same image already fetched for classification is reused — no second upload — via `PdfImport#process_with_ai` and `extract_transactions` sharing the same rasterized/base64 payload if feasible, avoiding processing the image twice; if that turns out awkward to plumb through the existing method boundaries, the fallback is a second cheap vision call, acceptable given it's one image not a multi-page document).
- Prompt returns `{"date":"YYYY-MM-DD","merchant":"...","amount":0}` (single object, not an array — there is exactly one transaction per receipt in scope here).
- Same PYG amount-format rule already added to `BankStatementExtractor` (dot = thousands separator, no decimals) — literally reuse the `AMOUNT_FORMAT_RULE` constant rather than duplicating the string.
- Amount forced negative (a receipt is always a purchase/debit, same reasoning as the Android webhook design).
- Uses `Provider::Openai::BANK_STATEMENT_MODEL`/`BANK_STATEMENT_REQUEST_TIMEOUT` constants (renaming consideration: these are currently named for bank statements specifically; the implementation plan should decide whether to rename them to something extraction-task-neutral now that a second extractor uses them, e.g. `DOCUMENT_EXTRACTION_MODEL`, vs. leaving the name and accepting it's now used by two callers — a naming call to make during planning, not a blocking design question).

### Account assignment

No new decision needed — reuses the existing per-import account-assignment step already in the UI (`import_configuration_path`), same as a bank statement PDF. The user picks which account a receipt's single row belongs to when reviewing it, exactly like they already do for statement rows today.

### Testing

- Unit test for `ReceiptExtractor` against a fixture receipt image (need to create or source one — a synthetic test image with known merchant/date/amount is enough, doesn't need to be a real scanned document).
- `ProcessPdfJob` test: a `receipt`-classified import generates exactly one row and reaches `pending` status.
- Controller test: uploading a `.jpg` reaches `create_pdf_import` (currently untested since it was unreachable for images).

## Open items deferred

- Whether to reuse the single vision call across classification + extraction, or accept two calls per receipt — a plumbing decision for the implementation plan, not a blocking design question (either is fine; a receipt is cheap either way since it's one image, unlike a multi-page statement).
- Renaming `BANK_STATEMENT_MODEL`/`BANK_STATEMENT_REQUEST_TIMEOUT` now that a second extractor uses them — implementation-time naming call, not a design blocker.
