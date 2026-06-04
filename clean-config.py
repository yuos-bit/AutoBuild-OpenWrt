import os
from tkinter import messagebox, Label, Button, Frame, filedialog
from tkinterdnd2 import TkinterDnD, DND_FILES


def process_config(file_path, output_dir):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        cleaned_lines = []
        was_empty = False  # 标记上一行是否为空行

        for line in lines:
            stripped_line = line.strip()

            # 1. 剔除所有以 # 开头的行
            if stripped_line.startswith("#"):
                continue

            # 2. 处理空行逻辑
            if stripped_line == "":
                if was_empty:
                    # 如果上一行已经是空行，则跳过当前空行
                    continue
                else:
                    was_empty = True
            else:
                # 当前行是有效配置，重置空行标记
                was_empty = False

            cleaned_lines.append(line)

        original_filename = os.path.basename(file_path)
        save_path = os.path.join(output_dir, original_filename)

        with open(save_path, "w", encoding="utf-8") as f:
            f.writelines(cleaned_lines)

        messagebox.showinfo("成功", f"文件已成功保存至：\n{save_path}")

    except Exception as e:
        messagebox.showerror("错误", f"处理失败：\n{str(e)}")


def drop(event):
    file_path = event.data.strip("{}")

    if not file_path.endswith(".config"):
        messagebox.showwarning("提示", "请拖入以 .config 结尾的配置文件！")
        return

    output_dir = filedialog.askdirectory(title="请选择保存过滤后文件的目录")
    if not output_dir:
        return

    process_config(file_path, output_dir)


# 初始化支持拖拽的窗口
root = TkinterDnD.Tk()
root.title("OpenWrt配置文件精简器")
root.geometry("400x250")

drop_frame = Frame(root, bd=2, relief="groove", bg="#f0f0f0")
drop_frame.pack(fill="both", expand=True, padx=20, pady=20)

label = Label(
    drop_frame,
    text="【请将 .config 文件拖动到此处】\n(将剔除所有 # 行，并将连续空行合并为一行)",
    bg="#f0f0f0",
    font=("Helvetica", 11),
)
label.pack(expand=True)

drop_frame.drop_target_register(DND_FILES)
drop_frame.dnd_bind("<<Drop>>", drop)

root.mainloop()