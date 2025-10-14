import re
import os

# 寄存器名称到编号的映射表
REGISTER_MAP = {
    'x0': 0, 'zero': 0, 'r0': 0,
    'x1': 1, 'ra': 1, 'r1': 1,
    'x2': 2, 'sp': 2,
    'x3': 3, 'gp': 3,
    'x4': 4, 'tp': 4,
    'x5': 5, 't0': 5,
    'x6': 6, 't1': 6,
    'x7': 7, 't2': 7,
    'x8': 8, 's0': 8, 'fp': 8,
    'x9': 9, 's1': 9,
    'x10': 10, 'a0': 10,
    'x11': 11, 'a1': 11,
    'x12': 12, 'a2': 12,
    'x13': 13, 'a3': 13,
    'x14': 14, 'a4': 14,
    'x15': 15, 'a5': 15,
    'x16': 16, 'a6': 16,
    'x17': 17, 'a7': 17,
    'x18': 18, 's2': 18,
    'x19': 19, 's3': 19,
    'x20': 20, 's4': 20,
    'x21': 21, 's5': 21,
    'x22': 22, 's6': 22,
    'x23': 23, 's7': 23,
    'x24': 24, 's8': 24,
    'x25': 25, 's9': 25,
    'x26': 26, 's10': 26,
    'x27': 27, 's11': 27,
    'x28': 28, 't3': 28,
    'x29': 29, 't4': 29,
    'x30': 30, 't5': 30,
    'x31': 31, 't6': 31,
}


# 指令信息库
INSTRUCTION_MAP = {
    # R-type
    'add':    {'type': 'R', 'opcode': '0110011', 'funct3': '000', 'funct7': '0000000'},
    'sub':    {'type': 'R', 'opcode': '0110011', 'funct3': '000', 'funct7': '0100000'},
    'sll':    {'type': 'R', 'opcode': '0110011', 'funct3': '001', 'funct7': '0000000'},
    'slt':    {'type': 'R', 'opcode': '0110011', 'funct3': '010', 'funct7': '0000000'},
    'sltu':   {'type': 'R', 'opcode': '0110011', 'funct3': '011', 'funct7': '0000000'},
    'xor':    {'type': 'R', 'opcode': '0110011', 'funct3': '100', 'funct7': '0000000'},
    'srl':    {'type': 'R', 'opcode': '0110011', 'funct3': '101', 'funct7': '0000000'},
    'sra':    {'type': 'R', 'opcode': '0110011', 'funct3': '101', 'funct7': '0100000'},
    'or':     {'type': 'R', 'opcode': '0110011', 'funct3': '110', 'funct7': '0000000'},
    'and':    {'type': 'R', 'opcode': '0110011', 'funct3': '111', 'funct7': '0000000'},
    # R-type (RV32M Extension)
    'mul':    {'type': 'R', 'opcode': '0110011', 'funct3': '000', 'funct7': '0000001'},
    'mulh':   {'type': 'R', 'opcode': '0110011', 'funct3': '001', 'funct7': '0000001'},
    'mulhsu': {'type': 'R', 'opcode': '0110011', 'funct3': '010', 'funct7': '0000001'},
    'mulhu':  {'type': 'R', 'opcode': '0110011', 'funct3': '011', 'funct7': '0000001'},
    'div':    {'type': 'R', 'opcode': '0110011', 'funct3': '100', 'funct7': '0000001'},
    'divu':   {'type': 'R', 'opcode': '0110011', 'funct3': '101', 'funct7': '0000001'},
    'rem':    {'type': 'R', 'opcode': '0110011', 'funct3': '110', 'funct7': '0000001'},
    'remu':   {'type': 'R', 'opcode': '0110011', 'funct3': '111', 'funct7': '0000001'},
    # I-type
    'addi':   {'type': 'I', 'opcode': '0010011', 'funct3': '000'},
    'slti':   {'type': 'I', 'opcode': '0010011', 'funct3': '010'},
    'sltiu':  {'type': 'I', 'opcode': '0010011', 'funct3': '011'},
    'xori':   {'type': 'I', 'opcode': '0010011', 'funct3': '100'},
    'ori':    {'type': 'I', 'opcode': '0010011', 'funct3': '110'},
    'andi':   {'type': 'I', 'opcode': '0010011', 'funct3': '111'},
    'slli':   {'type': 'I-shift', 'opcode': '0010011', 'funct3': '001', 'funct7': '0000000'},
    'srli':   {'type': 'I-shift', 'opcode': '0010011', 'funct3': '101', 'funct7': '0000000'},
    'srai':   {'type': 'I-shift', 'opcode': '0010011', 'funct3': '101', 'funct7': '0100000'},
    'lb':     {'type': 'I-load', 'opcode': '0000011', 'funct3': '000'},
    'lh':     {'type': 'I-load', 'opcode': '0000011', 'funct3': '001'},
    'lw':     {'type': 'I-load', 'opcode': '0000011', 'funct3': '010'},
    'lbu':    {'type': 'I-load', 'opcode': '0000011', 'funct3': '100'},
    'lhu':    {'type': 'I-load', 'opcode': '0000011', 'funct3': '101'},
    'jalr':   {'type': 'I', 'opcode': '1100111', 'funct3': '000'},
    # S-type
    'sb':     {'type': 'S', 'opcode': '0100011', 'funct3': '000'},
    'sh':     {'type': 'S', 'opcode': '0100011', 'funct3': '001'},
    'sw':     {'type': 'S', 'opcode': '0100011', 'funct3': '010'},
    # B-type
    'beq':    {'type': 'B', 'opcode': '1100011', 'funct3': '000'},
    'bne':    {'type': 'B', 'opcode': '1100011', 'funct3': '001'},
    'blt':    {'type': 'B', 'opcode': '1100011', 'funct3': '100'},
    'bge':    {'type': 'B', 'opcode': '1100011', 'funct3': '101'},
    'bltu':   {'type': 'B', 'opcode': '1100011', 'funct3': '110'},
    'bgeu':   {'type': 'B', 'opcode': '1100011', 'funct3': '111'},
    # U-type
    'lui':    {'type': 'U', 'opcode': '0110111'},
    'auipc':  {'type': 'U', 'opcode': '0010111'},
    # J-type
    'jal':    {'type': 'J', 'opcode': '1101111'},
}

# 将一个十进制数转换为指定位数的二进制补码字符串
def to_signed_binary(num, bits):
    if num >= 0:
        # format(value, '0_width_b')
        return format(num, f'0{bits}b')
    else:
        # Two's complement for negative numbers
        return format((1 << bits) + num, f'0{bits}b')


# 各类型指令处理器
def get_reg_num(reg_name):
    # 通过名称查找寄存器编号
    return REGISTER_MAP.get(reg_name.lower())

def handle_r_type(instr, operands):
    rd_name, rs1_name, rs2_name = operands[0], operands[1], operands[2]

    rd_num = get_reg_num(rd_name)
    if rd_num is None: return None, f"无效的目标寄存器 (rd): '{rd_name}'"

    rs1_num = get_reg_num(rs1_name)
    if rs1_num is None: return None, f"无效的源寄存器 (rs1): '{rs1_name}'"

    rs2_num = get_reg_num(rs2_name)
    if rs2_num is None: return None, f"无效的源寄存器 (rs2): '{rs2_name}'"

    rd, rs1, rs2 = format(rd_num, '05b'), format(rs1_num, '05b'), format(rs2_num, '05b')
    return instr['funct7'] + rs2 + rs1 + instr['funct3'] + rd + instr['opcode'], None

def handle_i_type(instr, operands):
    rd_name, rs1_name = operands[0], operands[1]

    rd_num = get_reg_num(rd_name)
    if rd_num is None: return None, f"无效的目标寄存器 (rd): '{rd_name}'"

    rs1_num = get_reg_num(rs1_name)
    if rs1_num is None: return None, f"无效的源寄存器 (rs1): '{rs1_name}'"

    rd, rs1 = format(rd_num, '05b'), format(rs1_num, '05b')
    imm = to_signed_binary(int(operands[2], 0), 12)
    return imm + rs1 + instr['funct3'] + rd + instr['opcode'], None

def handle_i_shift_type(instr, operands):
    rd_name, rs1_name = operands[0], operands[1]

    rd_num = get_reg_num(rd_name)
    if rd_num is None: return None, f"无效的目标寄存器 (rd): '{rd_name}'"

    rs1_num = get_reg_num(rs1_name)
    if rs1_num is None: return None, f"无效的源寄存器 (rs1): '{rs1_name}'"

    rd, rs1 = format(rd_num, '05b'), format(rs1_num, '05b')
    shamt = format(int(operands[2], 0), '05b')
    return instr['funct7'] + shamt + rs1 + instr['funct3'] + rd + instr['opcode'], None

def handle_i_load_type(instr, operands):
    rd_name, rs1_name = operands[0], operands[2]

    rd_num = get_reg_num(rd_name)
    if rd_num is None: return None, f"无效的目标寄存器 (rd): '{rd_name}'"

    rs1_num = get_reg_num(rs1_name)
    if rs1_num is None: return None, f"无效的基址寄存器 (rs1): '{rs1_name}'"

    rd, rs1 = format(rd_num, '05b'), format(rs1_num, '05b')
    imm = to_signed_binary(int(operands[1], 0), 12)
    return imm + rs1 + instr['funct3'] + rd + instr['opcode'], None

def handle_s_type(instr, operands):
    rs2_name, rs1_name = operands[0], operands[2]

    rs2_num = get_reg_num(rs2_name)
    if rs2_num is None: return None, f"无效的源寄存器 (rs2): '{rs2_name}'"

    rs1_num = get_reg_num(rs1_name)
    if rs1_num is None: return None, f"无效的基址寄存器 (rs1): '{rs1_name}'"

    rs2, rs1 = format(rs2_num, '05b'), format(rs1_num, '05b')
    imm = to_signed_binary(int(operands[1], 0), 12)
    imm11_5, imm4_0 = imm[0:7], imm[7:12]
    return imm11_5 + rs2 + rs1 + instr['funct3'] + imm4_0 + instr['opcode'], None


def handle_b_type(instr, operands):
    op1_name, op2_name = operands[0], operands[1]
    # 如果是伪指令 (ble)，交换操作数
    if instr.get('swap_operands', False):
        op1_name, op2_name = op2_name, op1_name

    rs1_num = get_reg_num(op1_name)
    if rs1_num is None: return None, f"无效的源寄存器 (rs1): '{op1_name}'"

    rs2_num = get_reg_num(op2_name)
    if rs2_num is None: return None, f"无效的源寄存器 (rs2): '{op2_name}'"

    rs1, rs2 = format(rs1_num, '05b'), format(rs2_num, '05b')
    imm_val = int(operands[2], 0)
    imm12 = (imm_val >> 12) & 1; imm11 = (imm_val >> 11) & 1
    imm10_5 = (imm_val >> 5) & 0b111111; imm4_1 = (imm_val >> 1) & 0b1111
    imm12_bin, imm11_bin = format(imm12, '01b'), format(imm11, '01b')
    imm10_5_bin, imm4_1_bin = format(imm10_5, '06b'), format(imm4_1, '04b')
    return imm12_bin + imm10_5_bin + rs2 + rs1 + instr['funct3'] + imm4_1_bin + imm11_bin + instr['opcode'], None


def handle_u_type(instr, operands):
    rd_name = operands[0]

    rd_num = get_reg_num(rd_name)
    if rd_num is None: return None, f"无效的目标寄存器 (rd): '{rd_name}'"

    rd = format(rd_num, '05b')
    imm = to_signed_binary(int(operands[1], 0), 20)
    return imm + rd + instr['opcode'], None

def handle_j_type(instr, operands):
    rd_name = operands[0]

    rd_num = get_reg_num(rd_name)
    if rd_num is None: return None, f"无效的目标寄存器 (rd): '{rd_name}'"

    rd = format(rd_num, '05b')
    imm_val = int(operands[1], 0)

    imm20 = (imm_val >> 20) & 1
    imm19_12 = (imm_val >> 12) & 0xff
    imm11 = (imm_val >> 11) & 1
    imm10_1 = (imm_val >> 1) & 0x3ff

    imm20_bin = format(imm20, '01b')
    imm19_12_bin = format(imm19_12, '08b')
    imm11_bin = format(imm11, '01b')
    imm10_1_bin = format(imm10_1, '010b')

    return imm20_bin + imm10_1_bin + imm11_bin + imm19_12_bin + rd + instr['opcode'], None


def clean_line(line):
    return line.split('#')[0].split('//')[0].strip()

def first_pass(lines):
    symbol_table = {}
    address = 0
    for line in lines:
        cleaned = clean_line(line)
        if not cleaned: continue
        label_match = re.match(r'^\s*([a-zA-Z_]\w*):\s*$', cleaned)
        label_with_instr_match = re.match(r'^\s*([a-zA-Z_]\w*):\s*(.*)', cleaned)
        if label_match:
            symbol_table[label_match.group(1).lower()] = address
        elif label_with_instr_match:
            label = label_with_instr_match.group(1).lower()
            instr = label_with_instr_match.group(2).strip()
            symbol_table[label] = address
            if instr: address += 4
        else: address += 4
    return symbol_table, None

def second_pass(lines, symbol_table):
    machine_codes = []
    address = 0
    errors = []
    for line_num, line in enumerate(lines, 1):
        cleaned = clean_line(line)
        if ':' in cleaned:
            cleaned = re.sub(r'^\s*[a-zA-Z_]\w*:\s*', '', cleaned).strip()
        if not cleaned: continue
        try:
            mnemonic_lower = cleaned.split()[0].lower()
            if mnemonic_lower not in INSTRUCTION_MAP:
                errors.append(f"第 {line_num} 行: 未知指令 '{mnemonic_lower}'")
                address += 4
                continue
        except IndexError:
            address += 4
            continue

        instr_info = INSTRUCTION_MAP[mnemonic_lower]
        instr_type = instr_info['type']

        reg = r'([a-zA-Z0-9]+)'
        imm = r'(-?0x[0-9a-fA-F]+|-?\d+)' # 允许十六进制和十进制
        label = r'[a-zA-Z_]\w*'
        target = f'({imm}|{label})'

        patterns = [
            (rf'{reg},\s*{reg},\s*{reg}', ('R')),
            (rf'{reg},\s*{reg},\s*{target}', ('I', 'I-shift', 'B')),
            (rf'{reg},\s*{imm}\({reg}\)', ('S', 'I-load')),
            (rf'{reg},\s*{target}', ('U', 'J')),
        ]

        line_to_parse = ' '.join(cleaned.split()[1:])

        matched = False
        for pattern, types in patterns:
            if instr_type not in types: continue
            match = re.fullmatch(pattern, line_to_parse.lower())
            if match:
                operands = list(match.groups())

                # 清理由于正则表达式OR操作产生的None值
                operands = [op for op in operands if op is not None]

                if instr_type in ('B', 'J'):
                    op_target = operands[-1]
                    offset = 0
                    try:
                        offset = int(op_target, 0)
                    except ValueError:
                        target_lower = op_target.lower()
                        if target_lower not in symbol_table:
                            errors.append(f"第 {line_num} 行: 未定义的标签 '{op_target}'")
                            matched = True; break

                        target_address = symbol_table[target_lower]
                        offset = target_address - address

                    operands[-1] = str(offset)

                # print("即将处理的操作数:", operands)

                handler_map = {
                    'R': handle_r_type, 'I': handle_i_type, 'I-shift': handle_i_shift_type,
                    'I-load': handle_i_load_type, 'S': handle_s_type, 'B': handle_b_type,
                    'U': handle_u_type, 'J': handle_j_type,
                }

                code, err = handler_map[instr_type](instr_info, operands)
                if err:
                    errors.append(f"第 {line_num} 行 ({cleaned}): {err}")
                else:
                    machine_codes.append(code)
                matched = True
                break

        if not matched and not any(f"第 {line_num} 行" in e for e in errors):
            errors.append(f"第 {line_num} 行: 无法解析的操作数格式 '{line_to_parse}'")

        address += 4
    return machine_codes, errors

def assemble(input_file_path, output_file_path):
    try:
        with open(input_file_path, 'r', encoding='utf-8') as infile:
            lines = infile.readlines()
    except FileNotFoundError:
        print(f"错误: 输入文件 '{input_file_path}' 未找到。")
        return
    except Exception as e:
        print(f"读取文件时发生错误: {e}")
        return

    symbol_table, err = first_pass(lines)
    if err:
        print(f"第一遍扫描出错误: {err}")
        return

    machine_codes, errors = second_pass(lines, symbol_table)

    if errors:
        print("汇编过程中发现错误:")
        for e in errors: print(f"- {e}")
        print("由于存在错误，未生成输出文件。")
        return

    try:
        with open(output_file_path, 'w', encoding='utf-8') as outfile:
            for code in machine_codes:
                outfile.write(code + '\n')
        print(f"汇编成功！共 {len(machine_codes)} 条指令。机器码已保存至 '{output_file_path}'。")
    except Exception as e:
        print(f"写入输出文件时发生错误: {e}")

# ==============================================================================
# 使用示例
# ==============================================================================
script_path = os.path.abspath(__file__)
project_root = os.path.dirname(os.path.dirname(script_path))
input_filename = os.path.join(project_root, 'data', 'input.txt')
output_filename = os.path.join(project_root, 'data', 'output.txt')

assemble(input_filename, output_filename)