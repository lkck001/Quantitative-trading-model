import os
from pypdf import PdfReader

# Configuration
PDF_PATH = r"docs/References/爱思潘交易系统.pdf"
BASE_DIR = r"docs/System_Architecture/Opportunity_Recognition/Triangle_Pattern_Recognition"
TEXT_DIR = os.path.join(BASE_DIR, "text")
IMG_DIR = os.path.join(BASE_DIR, "images")

# Specific page ranges for "上三交易机会" (Upper Triangle) and "下三交易机会" (Lower Triangle)
# Based on TOC:
# 4.4 上三交易机会: Page 63-66 (PDF Pages approx 76-79)
# 4.5 下三交易机会: Page 67-69 (PDF Pages approx 80-82)
# We will target PDF pages 76 to 83 to be safe and filter by content headers.

TARGET_PAGES = range(75, 84) # 0-indexed: 75 is page 76

def setup_dirs():
    if not os.path.exists(TEXT_DIR):
        os.makedirs(TEXT_DIR)
    if not os.path.exists(IMG_DIR):
        os.makedirs(IMG_DIR)

def extract_content():
    if not os.path.exists(PDF_PATH):
        print(f"Error: {PDF_PATH} not found.")
        return

    reader = PdfReader(PDF_PATH)
    print(f"Scanning target pages {TARGET_PAGES}...")

    text_output_path = os.path.join(TEXT_DIR, "triangle_opportunities.md")
    
    with open(text_output_path, "w", encoding="utf-8") as f:
        f.write("# 爱思潘交易系统 - 上三/下三交易机会详解\n\n")
        
        capturing = False
        
        for i in TARGET_PAGES:
            if i >= len(reader.pages):
                break
                
            page = reader.pages[i]
            page_num = i + 1
            text = page.extract_text()
            
            # Logic to start/stop capturing based on section headers
            # Note: OCR text might have spaces or slight variations
            if "4.4" in text and "上三交易机会" in text:
                capturing = True
                f.write(f"## Section 4.4 Starts (Page {page_num})\n\n")
            
            # If we hit 4.6, stop capturing
            if "4.6" in text:
                capturing = False
                print(f"Stopped capturing at Section 4.6 on page {page_num}")
                break

            if capturing or ("4.5" in text and "下三交易机会" in text):
                # Ensure we capture 4.5 start even if 4.4 flag wasn't set (though it should be)
                if "4.5" in text and "下三交易机会" in text:
                    capturing = True
                    f.write(f"## Section 4.5 Starts (Page {page_num})\n\n")
                
                print(f"Extracting content from Page {page_num}")
                f.write(f"### Page {page_num}\n\n")
                f.write(text)
                f.write("\n\n")
                
                # Extract images ONLY for these pages
                try:
                    for img_file in page.images:
                        img_name = f"page_{page_num}_{img_file.name}"
                        img_path = os.path.join(IMG_DIR, img_name)
                        
                        with open(img_path, "wb") as img_f:
                            img_f.write(img_file.data)
                        
                        f.write(f"![{img_name}](../../Triangle_Pattern_Recognition/images/{img_name})\n\n")
                        print(f"  Extracted image: {img_name}")
                except Exception as e:
                    print(f"  Warning: Failed to extract images from page {page_num}: {e}")
                
                f.write("---\n\n")

    print(f"Extraction complete. Text saved to {text_output_path}")
    print(f"Images saved to {IMG_DIR}")

if __name__ == "__main__":
    setup_dirs()
    extract_content()
