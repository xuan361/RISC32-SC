import serial
import time
import sys

# --- 配置参数 ---
SERIAL_PORT = "COM9"  # 串口号
BAUD_RATE = 9600  # 波特率
TIMEOUT = None  # 设置为 None 表示阻塞读取，直到接收到所需字节数

# 示例：要发送给开发板的字节数据
# 在实际应用中，你可能需要根据接收到的数据来决定要发送什么。
# 这里使用 b'\xAA' 作为示例要发送的字节。
SEND_BYTE = b"\xaa"


def serial_comm_loop(port, baudrate, send_data):
    """
    与开发板（运行了包含 Uart.v 模块的固件）进行收发交互的程序。
    先等待接收一字节数据，接收到后发送一字节数据，然后重复。
    """
    ser = None
    try:
        # 打开串口
        # timeout=None 确保 ser.read(1) 会阻塞，直到接收到 1 字节数据
        ser = serial.Serial(port, baudrate, timeout=TIMEOUT)
        print(f"成功打开串口: {port} @ {baudrate} bps")
        print("等待开发板发送第一个字节...")

        while True:
            # 1. 阻塞等待接收一字节数据
            # 对应 Uart.v 模块的 RX 逻辑接收
            received_data = ser.read(1)

            if received_data:
                # 接收到数据
                # received_data 是 bytes 类型，例如 b'\x01'
                print(
                    f"接收到 (RX): {received_data.hex()} (ASCII: {received_data.decode('latin-1') if 0x20 <= received_data[0] <= 0x7E else '非可见字符'})"
                )

                # 2. 发送一字节数据
                # 对应 Uart.v 模块的 TX 逻辑发送
                # 示例：发送预设的字节。如果你想回送接收到的数据，可以使用 ser.write(received_data)

                # 示例：根据接收到的数据修改发送数据 (例如递增)
                byte_to_send = bytes([(received_data[0] + 1) % 256])

                print(f"发送 (TX): {byte_to_send.hex()}")
                ser.write(byte_to_send)

            else:
                # 在 timeout=None 的情况下，理论上不会到达这里
                print("未接收到数据。")

    except serial.SerialException as e:
        print(f"\n[错误] 串口操作失败: {e}", file=sys.stderr)
        if ser and ser.is_open:
            ser.close()
    except KeyboardInterrupt:
        print("\n[退出] 程序被用户中断。")
    except Exception as e:
        print(f"\n[错误] 发生未知错误: {e}", file=sys.stderr)
    finally:
        # 确保在程序结束时关闭串口
        if ser and ser.is_open:
            ser.close()
            print("串口已关闭。")


if __name__ == "__main__":
    # 调用主循环函数
    serial_comm_loop(SERIAL_PORT, BAUD_RATE, SEND_BYTE)
