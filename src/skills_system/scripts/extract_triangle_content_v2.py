import os
from pypdf import PdfReader

# Configuration
PDF_PATH = r"src/AsipanEnergyTradingSystem/docs/References/爱思潘交易系统.pdf"
BASE_DIR = r"src/AsipanEnergyTradingSystem/docs/System_Architecture/Opportunity_Recognition/Triangle_Pattern_Recognition"
TEXT_DIR = os.path.join(BASE_DIR, "text")
IMG_DIR = os.path.join(BASE_DIR, "images")

# Keywords to search for
KEYWORDS = ["上三交易机会", "下三交易机会", "三角形"]

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
    print(f"Scanning {len(reader.pages)} pages...")

    # File to store extracted text
    text_output_path = os.path.join(TEXT_DIR, "triangle_content.md")
    
    with open(text_output_path, "w", encoding="utf-8") as f:
        f.write("# 爱思潘交易系统 - 三角形形态图文摘录\n\n")
        
        for i, page in enumerate(reader.pages):
            page_num = i + 1
            text = page.extract_text()
            
            # Check if any keyword is in the text
            if any(k in text for k in KEYWORDS):
                print(f"Found keywords on page {page_num}")
                
                # Write text
                f.write(f"## Page {page_num}\n\n")
                f.write(text)
                f.write("\n\n")
                
                # Extract images
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
