import os
import subprocess
import argparse

WORKSPACE="/home/gain/unikraft/apps_size"
UNIKERNEL="lib-helloworld"


import re

def reorder_object_file(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    updated_lines = []
    updated_lines.append("#!/bin/bash\n")

    for line in lines:
        if "gcc -r" in line:  # Identify the gcc command

            # Split the line into components
            parts = line.strip().split()
            str_remove= ['-Wl,--start-group', '-Wl,--end-group', '-o']
            for st in str_remove:
                parts.remove(st)
            obj_files = [p for p in parts if p.endswith(".o")]

            # Find the object file with "build/app"
            app_obj = None
            for i, obj in enumerate(obj_files):
                if "build/app" in obj:
                    app_obj = obj
                elif "unikernel_kvmfc-x86_64.ld.o" in obj:
                    print(obj_files[i])
                    obj_files[i] = "-Wl,--start-group -Wl,--end-group -o " + obj_files[i]
            
            # If found, reorder the object file
            if app_obj:
                obj_files.remove(app_obj)
                obj_files.insert(0, app_obj)
                # Reconstruct the command
                updated_line = " ".join(part if not part.endswith(".o") else "" for part in parts) + " " + " ".join(obj_files) + "\n"
                updated_lines.append(updated_line)
            else:
                updated_lines.append(line)
        elif "make[1]:" in line:
            continue
        else:
            updated_lines.append(line)

    with open(output_file, 'w') as f:
        f.writelines(updated_lines)

def main():
    
    parser = argparse.ArgumentParser()
    parser.add_argument('-w',  '--workspace',help='Workspace directory', type=str, default=WORKSPACE)
    
    args = parser.parse_args()
    input_file = os.path.join(args.workspace, "build/cmd.sh")
    reorder_object_file(input_file, input_file)
    print(f"Updated command written to {input_file}")
    
if __name__ == "__main__":
    main()