from pypdf import PdfReader
import os

pdf_path = "src/AsipanEnergyTradingSystem/docs/References/爱思潘交易系统.pdf"
output_path = "src/AsipanEnergyTradingSystem/docs/References/book_summary.md"

if not os.path.exists(pdf_path):
    print(f"Error: {pdf_path} not found.")
    exit(1)

reader = PdfReader(pdf_path)
total_pages = len(reader.pages)

print(f"Processing {pdf_path} ({total_pages} pages)...")

with open(output_path, "w", encoding="utf-8") as f:
    f.write(f"# 摘要: 爱思潘交易系统\n\n")
    f.write(f"总页数: {total_pages}\n\n")
    
    # Extract text from first 20 pages (Introduction/Overview) and maybe random pages or specific chapters if I knew them
    # For now, let's just grab the whole thing but maybe truncate if too long
    # Actually, extracting everything to a file is safer, I can then read the file
    
    for i, page in enumerate(reader.pages):
        text = page.extract_text()
        if text:
            f.write(f"## Page {i+1}\n\n")
            f.write(text)
            f.write("\n\n---\n\n")

print(f"Done. Text extracted to {output_path}")
