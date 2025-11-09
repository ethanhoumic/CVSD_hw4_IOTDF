#!/usr/bin/env python3
"""
DES 加密工具 - 完整版本
支持批量加密和驗證功能
"""

from Crypto.Cipher import DES
import sys

class DESEncryptor:
    def __init__(self):
        pass
    
    def encrypt_line(self, key_hex, plaintext_hex):
        """
        加密單一行
        
        Args:
            key_hex: 16 個十六進位字符的 key
            plaintext_hex: 16 個十六進位字符的 plaintext
            
        Returns:
            加密後的十六進位字符串，或 None (錯誤)
        """
        try:
            # 轉換為大寫
            key_hex = key_hex.upper()
            plaintext_hex = plaintext_hex.upper()
            
            key = bytes.fromhex(key_hex)
            plaintext = bytes.fromhex(plaintext_hex)
            
            # DES 要求 key 是 8 bytes (64 bits)
            if len(key) != 8:
                raise ValueError(f"Key 長度必須是 8 bytes，得到 {len(key)}")
            
            # DES 要求 plaintext 是 8 bytes (64 bits)
            if len(plaintext) != 8:
                raise ValueError(f"Plaintext 長度必須是 8 bytes，得到 {len(plaintext)}")
            
            cipher = DES.new(key, DES.MODE_ECB)
            ciphertext = cipher.encrypt(plaintext)
            
            return ciphertext.hex().upper()
        
        except Exception as e:
            return None, str(e)
    
    def process_file(self, input_file, output_file, verbose=True):
        """
        批量處理檔案
        
        Args:
            input_file: 輸入檔案名稱
            output_file: 輸出檔案名稱
            verbose: 是否輸出詳細信息
            
        Returns:
            處理成功的行數
        """
        success_count = 0
        error_count = 0
        
        try:
            with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
                for line_num, line in enumerate(f_in, 1):
                    line = line.strip()
                    
                    # 跳過空行
                    if not line:
                        continue
                    
                    # 檢查行的格式
                    if len(line) != 32:
                        error_count += 1
                        if verbose:
                            print(f"❌ 第 {line_num} 行: 長度不是 32 (實際: {len(line)})")
                        continue
                    
                    key_hex = line[:16].upper()
                    plaintext_hex = line[16:32].upper()
                    
                    result = self.encrypt_line(key_hex, plaintext_hex)
                    
                    if isinstance(result, tuple):
                        error_count += 1
                        if verbose:
                            print(f"❌ 第 {line_num} 行: {result[1]}")
                    else:
                        ciphertext_hex = result.upper()
                        output_line = key_hex + ciphertext_hex
                        f_out.write(f"{output_line}\n")
                        success_count += 1
                        if verbose:
                            print(f"✓ 第 {line_num} 行: {key_hex} + {plaintext_hex} => {output_line}")
            
            return success_count, error_count
        
        except FileNotFoundError as e:
            print(f"❌ 錯誤: {e}")
            return 0, 0

def main():
    encryptor = DESEncryptor()
    
    # 配置
    input_file = "./pattern1_data/pattern1.dat"
    output_file = "pattern_encrypted.dat"
    
    print("=" * 60)
    print("DES 加密工具")
    print("=" * 60)
    print(f"輸入檔案: {input_file}")
    print(f"輸出檔案: {output_file}")
    print("=" * 60)
    
    success, error = encryptor.process_file(input_file, output_file, verbose=True)
    
    print("=" * 60)
    print(f"完成: {success} 行成功，{error} 行錯誤")
    print("=" * 60)

if __name__ == "__main__":
    main()