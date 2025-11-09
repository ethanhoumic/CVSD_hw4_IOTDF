def calculate_crc3(hex_string):
    """
    計算3位CRC (生成多項式: x³ + x² + 1 = 1101)
    
    參數：
    - hex_string: 32個16進位字符的字符串（128 bits）
    
    返回：
    - 3位的CRC值（0-7）
    """
    # 轉換為整數
    data = int(hex_string, 16)
    
    # 生成多項式: 1101 (二進制)
    poly = 0b1101
    
    # 將數據左移3位（補3個零）
    data = data << 3
    
    # 進行多項式除法（128位數據 + 3位補零 = 131位）
    for i in range(128):
        # 檢查當前最高位
        if data & (1 << (130 - i)):
            # 進行XOR操作
            data ^= (poly << (130 - i - 3))
    
    # 取最低3位作為CRC
    return data & 0b111


def crc_to_hex_128bit(crc_value):
    """
    將3位CRC值零擴展到128位，並轉換為16進位
    
    參數：
    - crc_value: 3位的CRC值（0-7）
    
    返回：
    - 32個16進位字符的字符串
    """
    # CRC在最右邊（最低位），前面補0到128位
    crc_128bit = crc_value
    
    # 轉換為16進位（32個字符）
    return f"{crc_128bit:032X}"


def process_pattern_file(input_file, output_file):
    """
    處理pattern檔案，計算每一行的CRC值並輸出結果
    
    參數：
    - input_file: 輸入檔案名稱（包含32個16進位字符的每一行）
    - output_file: 輸出檔案名稱（包含128位CRC值的16進位表示）
    """
    try:
        with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
            line_count = 0
            for line in f_in:
                line = line.strip()
                if line:  # 跳過空行
                    # 計算3位CRC
                    crc_3bit = calculate_crc3(line)
                    
                    # 轉換為128位16進位
                    crc_hex = crc_to_hex_128bit(crc_3bit)
                    
                    # 寫入輸出檔案
                    f_out.write(f"{crc_hex}\n")
                    
                    line_count += 1
        
        print(f"處理完成！")
        print(f"共處理 {line_count} 行")
        print(f"結果已保存到 {output_file}")
        
    except FileNotFoundError:
        print(f"錯誤：找不到檔案 {input_file}")
    except Exception as e:
        print(f"錯誤：{e}")


if __name__ == "__main__":
    input_file = "./pattern1_data/pattern1.dat"
    output_file = "pattern_crc.dat"
    
    process_pattern_file(input_file, output_file)