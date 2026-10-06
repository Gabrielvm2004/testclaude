"""Gera as 10 Ações Rápidas (.workflow) do Scout em scout/servicos/.

Rode de novo só se mudar a lista ATALHOS ou o código da Ação Rápida:
    python3 scout/ferramentas/gerar_workflows.py
Os nomes não têm acento de propósito: assim o instalador consegue
configurar o atalho de teclado de cada um sem problema de codificação.
"""
import plistlib
import shutil
import uuid
from pathlib import Path

# tecla, nome da Ação Rápida, evento passado ao scout.applescript
ATALHOS = [
    ("0", "Scout 0 - Desfazer", "desfazer"),
    ("1", "Scout 1 - Posse nossa", "ganhamos_posse"),
    ("2", "Scout 2 - Posse deles", "perdemos_posse"),
    ("3", "Scout 3 - Finalizacao nossa", "finalizacao_nossa"),
    ("4", "Scout 4 - Finalizacao concedida", "finalizacao_concedida"),
    ("5", "Scout 5 - Subida de pressao", "subida_pressao"),
    ("6", "Scout 6 - Corrida para tras", "corrida_para_tras"),
    ("7", "Scout 7 - Inicio 1o tempo", "inicio_1t"),
    ("8", "Scout 8 - Inicio 2o tempo", "inicio_2t"),
    ("9", "Scout 9 - Novo jogo", "novo_jogo"),
]

CODIGO = """on run {input, parameters}
\tset scout to (POSIX path of (path to documents folder)) & "Scout/sistema/scout.applescript"
\trun script ((POSIX file scout) as alias) with parameters {"%s"}
\treturn input
end run"""

PADRAO_ACAO = """on run {input, parameters}
\t
\t(* Your script goes here *)
\t
\treturn input
end run"""

PASTA = Path(__file__).resolve().parent.parent / "servicos"


def uid(*partes):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "scout-america-fc/" + "/".join(partes))).upper()


def info_plist(nome):
    return {
        "NSServices": [{
            "NSBackgroundColorName": "background",
            "NSIconName": "NSActionTemplate",
            "NSMenuItem": {"default": nome},
            "NSMessage": "runWorkflowAsService",
        }]
    }


def document_wflow(nome, evento):
    acao = {
        "AMAccepts": {"Container": "List", "Optional": True, "Types": ["com.apple.applescript.object"]},
        "AMActionVersion": "1.0.2",
        "AMApplication": ["Automator"],
        "AMParameterProperties": {"source": {}},
        "AMProvides": {"Container": "List", "Types": ["com.apple.applescript.object"]},
        "ActionBundlePath": "/System/Library/Automator/Run AppleScript.action",
        "ActionName": "Run AppleScript",
        "ActionParameters": {"source": CODIGO % evento},
        "BundleIdentifier": "com.apple.Automator.RunScript",
        "CFBundleVersion": "1.0.2",
        "CanShowSelectedItemsWhenRun": False,
        "CanShowWhenRun": True,
        "Category": ["AMCategoryUtilities"],
        "Class Name": "RunScriptAction",
        "InputUUID": uid(nome, "input"),
        "Keywords": ["Run"],
        "OutputUUID": uid(nome, "output"),
        "UUID": uid(nome, "acao"),
        "UnlocalizedApplications": ["Automator"],
        "arguments": {"0": {
            "default value": PADRAO_ACAO,
            "name": "source", "required": "0", "type": "0", "uuid": "0",
        }},
        "isViewVisible": True,
        "location": "309.000000:253.000000",
        "nibPath": "/System/Library/Automator/Run AppleScript.action/Contents/Resources/Base.lproj/main.nib",
    }
    return {
        "AMApplicationBuild": "492",
        "AMApplicationVersion": "2.10",
        "AMDocumentVersion": "2",
        "actions": [{"action": acao, "isViewVisible": True}],
        "connectors": {},
        "workflowMetaData": {
            "applicationBundleIDsByPath": {},
            "applicationPaths": [],
            "inputTypeIdentifier": "com.apple.Automator.nothing",
            "outputTypeIdentifier": "com.apple.Automator.nothing",
            "presentationMode": 11,
            "processesInput": False,
            "serviceInputTypeIdentifier": "com.apple.Automator.nothing",
            "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
            "serviceProcessesInput": False,
            "systemImageName": "NSActionTemplate",
            "useAutomaticInputType": False,
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
        },
    }


def main():
    if PASTA.exists():
        shutil.rmtree(PASTA)
    for tecla, nome, evento in ATALHOS:
        conteudo = PASTA / f"{nome}.workflow" / "Contents"
        conteudo.mkdir(parents=True)
        with open(conteudo / "Info.plist", "wb") as f:
            plistlib.dump(info_plist(nome), f)
        with open(conteudo / "document.wflow", "wb") as f:
            plistlib.dump(document_wflow(nome, evento), f)
    # Lista lida pelo instalador: tecla<TAB>nome
    (PASTA / "atalhos.txt").write_text("".join(f"{t}\t{n}\n" for t, n, _ in ATALHOS))
    print(f"{len(ATALHOS)} Ações Rápidas geradas em {PASTA}")


if __name__ == "__main__":
    main()
