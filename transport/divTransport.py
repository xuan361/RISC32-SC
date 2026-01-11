import serial
import serial.tools.list_ports
import time
import sys


def list_ports():
    """列出当前可用的串口"""
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("[-] 未发现串口设备，请检查连接！")
        return None
    return ports


def main():
    print("=" * 50)
    print("      Python 串口除法器测试工具 (1字节模式)")
    print("=" * 50)

    # 1. 选择串口
    ports = list_ports()
    if not ports:
        return

    print("[*] 检测到以下串口:")
    for i, port in enumerate(ports):
        print(f"    {i}: {port.device} - {port.description}")

    try:
        idx = int(input("\n[?] 请输入串口序号 (例如 0): "))
        selected_port = ports[idx].device
    except (ValueError, IndexError):
        print("[-] 输入错误，程序退出")
        return

    # 2. 配置参数 (参考截图配置: 9600, 8, N, 1)
    baud_rate = 9600
    timeout_sec = 2  # 读取超时时间

    try:
        ser = serial.Serial(
            port=selected_port,
            baudrate=baud_rate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=timeout_sec,
        )
        print(f"\n[+] 串口 {selected_port} 打开成功 (波特率: {baud_rate})")
    except Exception as e:
        print(f"[-] 串口打开失败: {e}")
        return

    print("-" * 50)
    print("提示: 输入 'q' 或 'exit' 退出程序")
    print("提示: 请输入 0-255 之间的整数")
    print("-" * 50)

    try:
        while True:
            # 3. 获取用户输入
            user_input = input("\n[Input] 请输入被除数 (Dividend): ")
            if user_input.lower() in ["q", "exit"]:
                break

            try:
                dividend = int(user_input)
                divisor = int(input("        请输入除数   (Divisor):  "))

                # 检查数据范围 (1字节: 0-255)
                if not (0 <= dividend <= 255 and 0 <= divisor <= 255):
                    print("[-] 错误: 数值必须在 0-255 之间 (1字节)")
                    continue

            except ValueError:
                print("[-] 错误: 请输入有效的整数")
                continue

            # 4. 发送数据
            # 将两个整数打包成 hex 字节发送
            # bytes([x, y]) 会生成形如 b'\x0A\x02' 的数据
            send_data = bytes([dividend, divisor])
            ser.write(send_data)

            print(
                f"[TX] -> 0x{dividend:02X} 0x{divisor:02X} (发送: {dividend} / {divisor})"
            )

            # 5. 接收数据
            # 假设硬件返回2个字节: [商, 余数]
            # 如果硬件返回格式不同，这里需要相应调整 read(n) 的数量
            received_data = ser.read(2)

            if len(received_data) == 2:
                quotient = received_data[0]
                remainder = received_data[1]
                print(
                    f"[RX] <- 0x{quotient:02X} 0x{remainder:02X} (接收: 商={quotient}, 余={remainder})"
                )

                # 简单的本地验证（可选）
                if divisor != 0:
                    calc_q = dividend // divisor
                    calc_r = dividend % divisor
                    if calc_q == quotient and calc_r == remainder:
                        print("      [√] 结果正确")
                    else:
                        print("      [x] 结果与预期不符 (可能硬件逻辑不同)")
            elif len(received_data) == 0:
                print("[!] 接收超时: 硬件没有响应")
            else:
                # 接收到了数据，但长度不对
                hex_str = " ".join([f"{b:02X}" for b in received_data])
                print(f"[!] 接收数据长度异常 ({len(received_data)} bytes): {hex_str}")

    except KeyboardInterrupt:
        print("\n[*] 用户中断")
    finally:
        ser.close()
        print("[*] 串口已关闭")


if __name__ == "__main__":
    main()
