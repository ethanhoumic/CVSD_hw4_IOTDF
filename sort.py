#!/usr/bin/env python3
# -*- coding: utf-8 -*-

def process_pattern_file(input_file, output_file):
    """
    讀取 pattern1.dat，將每行 32 位十六進位數字解析為 16 個 8-bit 無號數，
    按大到小排序，輸出到 pattern_sort.dat
    """
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    sorted_lines = []
    
    for line in lines:
        line = line.strip()
        if not line:  # 跳過空行
            continue
        
        # 將 32 位十六進位數字分成 16 個 2 位的十六進位數字（每個代表一個 8-bit 無號數）
        numbers = []
        for i in range(0, 32, 2):
            hex_pair = line[i:i+2]
            number = int(hex_pair, 16)  # 轉換為十進位
            numbers.append(number)
        
        # 按大到小排序
        numbers.sort(reverse=True)
        
        # 轉換回十六進位字符串（大寫，每個 2 位）
        sorted_hex = ''.join(f'{num:02X}' for num in numbers)
        sorted_lines.append(sorted_hex)
    
    # 寫入輸出文件
    with open(output_file, 'w') as f:
        for line in sorted_lines:
            f.write(line + '\n')
    
    print(f"處理完成！")
    print(f"輸入文件: {input_file}")
    print(f"輸出文件: {output_file}")
    print(f"處理的行數: {len(sorted_lines)}")

if __name__ == "__main__":
    input_file = "./00_TESTBED/pattern1_data/pattern1.dat"
    output_file = "pattern_sort.dat"
    
    try:
        process_pattern_file(input_file, output_file)
    except FileNotFoundError:
        print(f"錯誤: 找不到文件 {input_file}")
    except Exception as e:
        print(f"發生錯誤: {e}")