"""Export versioned USB, SWD and BLE-DFU artifacts after a successful build."""

from pathlib import Path
import hashlib
import shutil
import subprocess

Import("env")


def export_artifacts(source, target, env):
    project_dir = Path(env.subst("$PROJECT_DIR"))
    build_dir = Path(env.subst("$BUILD_DIR"))
    program = env.subst("$PROGNAME")
    version = env.GetProjectOption("custom_yunsh_version")
    output_dir = project_dir / "dist"
    output_dir.mkdir(exist_ok=True)

    source_hex = build_dir / f"{program}.hex"
    source_zip = build_dir / f"{program}.zip"
    output_hex = output_dir / f"YUNSH-Glasses-nRF52840-v{version}.hex"
    output_zip = output_dir / f"YUNSH-Glasses-nRF52840-v{version}-dfu.zip"
    output_uf2 = output_dir / f"YUNSH-Glasses-nRF52840-v{version}.uf2"

    shutil.copy2(source_hex, output_hex)
    shutil.copy2(source_zip, output_zip)

    framework_dir = Path(
        env.PioPlatform().get_package_dir("framework-arduinoadafruitnrf52")
    )
    uf2_converter = framework_dir / "tools/uf2conv/uf2conv.py"
    subprocess.run(
        [
            env.subst("$PYTHONEXE"),
            str(uf2_converter),
            str(source_hex),
            "-c",
            "-f",
            "0xADA52840",
            "-o",
            str(output_uf2),
        ],
        check=True,
    )

    artifacts = (output_hex, output_uf2, output_zip)
    checksum_lines = []
    for artifact in artifacts:
        digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
        checksum_lines.append(f"{digest}  {artifact.name}")
    (output_dir / "SHA256SUMS").write_text(
        "\n".join(checksum_lines) + "\n", encoding="utf-8"
    )
    print(f"YUNSH firmware artifacts exported to {output_dir}")


env.AddPostAction("$BUILD_DIR/${PROGNAME}.zip", export_artifacts)
