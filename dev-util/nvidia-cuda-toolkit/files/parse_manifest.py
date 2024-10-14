#!/usr/bin/env python

import argparse
import xml.etree.ElementTree

import defusedxml.ElementTree
from pathlib import Path

verbose: bool = False

ind = "\t"
indent = 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('filename')  # positional argument
    parser.add_argument('-v', '--verbose',
                        action='store_true')  # on/off flag

    args = parser.parse_args()
    global verbose
    verbose = args.verbose

    basedir = Path(args.filename).parents[1]

    et = defusedxml.ElementTree.parse(args.filename)

    def p_components(el: xml.etree.ElementTree.Element):
        print("COMPONENTS=(")
        for node in el.findall("[@id='main']//package/[@name]"):
            name = node.get("name")

            if name.startswith("CUDA"):
                name2 = ' '.join(name.split(" ")[1:-1])
            else:
                name2 = name

            name2 = name2.replace(" ", "_")
            print(f"{ind * indent}{name2}")
        print(")")
        print()

    # p_components(et)

    for e in et.findall("[@id='main']/package"):
        def p_package(el: xml.etree.ElementTree.Element, level: int = 0):
            name = el.get("name")

            skip = {
                "Kernel Objects",
                "Driver",
                "Documentation",
                # "Demo Suite",
                "nsight",
            }

            if name.startswith("CUDA"):
                name2 = ' '.join(name.split(" ")[1:-1])
            else:
                name2 = name

            if name2 in skip:
                return

            name2 = name2.replace(" ", "_")

            path = ""

            print(f"{ind * (level + 0) * indent}if ! has {name2} \"${{SKIP_COMPONENTS[@]}}\"; then # \"{name}\"")

            for child in el:
                if child.tag == "package":
                    continue
                if child.tag == "file":
                    continue
                if child.tag == "desktopFile":
                    continue
                if child.tag == "pcfile":
                    continue
                for attrib in child.attrib:
                    print(f"{child.tag} {attrib}={child.attrib[attrib]}")

            for node in el.findall("./name"):
                print(f"{ind * (level + 1) * indent}# {node.tag}: \"{node.text}\"")

            # for node in el.findall("./type"):
            #     print(f"{ind * (level + 1) * indent}# {node.tag}: \"{node.text}\"")

            # for node in el.findall("./priority"):
            #     print(f"{ind * (level + 1) * indent}# {node.tag}: \"{node.text}\"")

            # for node in el.findall("./single-selection"):
            #     print(f"{ind * (level + 1) * indent}# {node.tag}: \"{node.text}\"")

            for node in el.findall("./koversion"):
                print(f"{ind * (level + 1) * indent}# {node.tag}: \"{node.text}\"")

            # for node in el.findall("./installPath"):
            #     print(f"{ind * (level + 1) * indent}# {node.tag}: \"{node.text}\"")

            for node in el.findall("./buildPath"):
                path = node.text.removeprefix('./')
                print(f"{ind * (level + 1) * indent}cd \"${{S}}/{path}\" || die \"cd ${{S}}/{path} failed\"")
                print()

            # for node in el.findall("./dir"):
            #     pass

            for node in el.findall("./file"):
                file = node.text.replace(".*", "*").replace(r"\.", ".").replace("x86_64", "${narch}").replace("sbsa", "${narch}")

                dir = ""
                if "dir" in node.attrib:
                    dir = f" \"{Path(node.attrib["dir"])}\""

                filepath = basedir / path / file

                if not filepath.is_symlink() and not file.endswith("-uninstaller"):
                    print(f"{ind * (level + 1) * indent}dofile \"{file}\"{dir}")

            for node in el.findall("./pcfile"):
                offset = node.text.rfind('-')
                if offset == -1:
                    raise RuntimeError(f"failed to split pcfile {node.text}")

                lib_name = node.text[:offset]

                if not node.text.endswith('.pc'):
                    raise RuntimeError(f"pcfile does not end in '.pc' {node.text}")
                lib_version = node.text[offset+1:-3]

                if "description" not in node.attrib:
                    raise RuntimeError(f"no description for {node.text}")

                subdir = ""
                if "subdir" in node.attrib:
                    subdir = f" \"{node.attrib["subdir"]}\""

                print(f"{ind * (level + 1) * indent}dopcfile "
                      f"\"{lib_name}\" "
                      f"\"{lib_version}\" "
                      f"\"{node.attrib["description"]}\"{subdir}")

            for node in el.findall("./desktopFile"):
                print(f"{ind * (level + 1) * indent}dodesktopFile \\")
                print(f"{ind * (level + 2) * indent}\"{node.attrib["filename"]}\" \\")
                print(f"{ind * (level + 2) * indent}\"{node.attrib["name"]}\" \\")
                print(f"{ind * (level + 2) * indent}\"{node.attrib["categories"]}\" \\")
                print(f"{ind * (level + 2) * indent}\"{node.attrib["keywords"]}\" \\")
                print(f"{ind * (level + 2) * indent}\"{node.attrib["iconPath"]}\" \\")
                print(f"{ind * (level + 2) * indent}\"{node.attrib["execPath"]}\" \\")
                print(f"{ind * (level + 2) * indent}\"{node.attrib["tryExecPath"]}\"")

            for node in el.findall("./package"):
                p_package(node, level + 1)

            print(f"{ind * (level + 0) * indent}fi")

        p_package(e)


if __name__ == "__main__":
    main()
