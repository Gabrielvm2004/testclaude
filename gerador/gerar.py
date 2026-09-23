#!/usr/bin/env python3
"""Gera o PDF de treino e controle de cada atleta a partir de dados/atletas/*.yaml.

Uso:
    python gerador/gerar.py                 # todos os atletas
    python gerador/gerar.py diego-avelar    # só um atleta
    python gerador/gerar.py --html          # também salva o HTML intermediário

Os PDFs ficam em saida/<atleta>/.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
import unicodedata
from collections import Counter, OrderedDict
from pathlib import Path

import qrcode
import qrcode.image.svg
import yaml
from jinja2 import Environment, FileSystemLoader, select_autoescape
from markupsafe import Markup

RAIZ = Path(__file__).resolve().parent.parent
DADOS = RAIZ / "dados"
DESIGN = RAIZ / "design-system"
MIDIA = RAIZ / "midia" / "exercicios"
SAIDA = RAIZ / "saida"

MESES = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
TITULOS_BLOCO = {
    "mobilidade": "Mobilidade",
    "ativacao": "Ativação",
    "principal": "Trabalho principal",
    "cardio": "Cardio",
    "finalizacao": "Finalização",
}


# ---------- utilidades ----------

def chave(nome: str) -> str:
    """Normaliza um nome de exercício para buscar na biblioteca."""
    nome = re.sub(r"\(.*?\)", "", str(nome))
    nome = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", nome.lower()).strip()


def como_data(valor) -> dt.date:
    if isinstance(valor, dt.date):
        return valor
    return dt.date.fromisoformat(str(valor))


def data_br(valor, formato: str = "curta") -> str:
    d = como_data(valor)
    if formato == "dia":
        return f"{d.day:02d}/{d.month:02d}"
    return f"{d.day:02d}/{d.month:02d}/{d.year}"


def qr_svg(url: str) -> Markup:
    img = qrcode.make(url, image_factory=qrcode.image.svg.SvgPathImage, border=1)
    svg = img.to_string(encoding="unicode")
    svg = re.sub(r"<\?xml.*?\?>", "", svg)
    return Markup(svg)


# ---------- gráficos (SVG simples, cores vindas dos tokens) ----------

def grafico_barras(rotulos: list[str], valores: list[float], largura=300, altura=140) -> Markup:
    if not valores:
        return Markup("")
    topo = max(valores) or 1
    margem_base, margem_topo = 22, 18
    area = altura - margem_base - margem_topo
    passo = largura / len(valores)
    barra = min(46, passo * 0.6)
    partes = [f'<svg viewBox="0 0 {largura} {altura}" role="img">']
    partes.append(
        f'<line x1="0" y1="{altura - margem_base}" x2="{largura}" y2="{altura - margem_base}" '
        f'stroke="var(--cor-linha)" stroke-width="1"/>'
    )
    for i, (rot, val) in enumerate(zip(rotulos, valores)):
        h = area * val / topo
        x = passo * i + (passo - barra) / 2
        y = altura - margem_base - h
        cx = x + barra / 2
        partes.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{barra:.1f}" height="{h:.1f}" rx="4" fill="var(--cor-destaque)"/>')
        partes.append(f'<text class="valor" x="{cx:.1f}" y="{y - 5:.1f}" text-anchor="middle">{val:g}</text>')
        partes.append(f'<text x="{cx:.1f}" y="{altura - 6}" text-anchor="middle">{rot}</text>')
    partes.append("</svg>")
    return Markup("".join(partes))


def grafico_barras_horizontais(rotulos: list[str], valores: list[float], largura=300) -> Markup:
    if not valores:
        return Markup("")
    linha, rotulo_w = 26, 112
    altura = linha * len(valores) + 4
    topo = max(valores) or 1
    area = largura - rotulo_w - 30
    partes = [f'<svg viewBox="0 0 {largura} {altura}" role="img">']
    for i, (rot, val) in enumerate(zip(rotulos, valores)):
        y = i * linha + 4
        w = max(4, area * val / topo)
        partes.append(f'<text x="0" y="{y + 14}">{rot}</text>')
        partes.append(f'<rect x="{rotulo_w}" y="{y + 2}" width="{w:.1f}" height="16" rx="4" fill="var(--cor-destaque)"/>')
        partes.append(f'<text class="valor" x="{rotulo_w + w + 6:.1f}" y="{y + 14}">{val:g}</text>')
    partes.append("</svg>")
    return Markup("".join(partes))


def grafico_linha(pontos: list[tuple[str, float]], unidade="", largura=300, altura=130) -> Markup:
    if len(pontos) < 2:
        return Markup("")
    valores = [v for _, v in pontos]
    minimo, maximo = min(valores), max(valores)
    if minimo == maximo:
        minimo, maximo = minimo - 1, maximo + 1
    mx, mt, mb = 24, 20, 22
    def px(i):
        return mx + (largura - 2 * mx) * i / (len(pontos) - 1)
    def py(v):
        return mt + (altura - mt - mb) * (1 - (v - minimo) / (maximo - minimo))
    caminho = " ".join(f"{'M' if i == 0 else 'L'}{px(i):.1f},{py(v):.1f}" for i, (_, v) in enumerate(pontos))
    partes = [f'<svg viewBox="0 0 {largura} {altura}" role="img">']
    partes.append(f'<path d="{caminho}" fill="none" stroke="var(--cor-destaque)" stroke-width="2.5" stroke-linejoin="round"/>')
    for i, (rot, v) in enumerate(pontos):
        partes.append(f'<circle cx="{px(i):.1f}" cy="{py(v):.1f}" r="4" fill="var(--cor-destaque)"/>')
        partes.append(f'<text class="valor" x="{px(i):.1f}" y="{py(v) - 8:.1f}" text-anchor="middle">{v:g}{unidade}</text>')
        partes.append(f'<text x="{px(i):.1f}" y="{altura - 6}" text-anchor="middle">{rot}</text>')
    partes.append("</svg>")
    return Markup("".join(partes))


# ---------- montagem dos dados ----------

def carregar_biblioteca() -> dict:
    caminho = DADOS / "exercicios.yaml"
    bruto = yaml.safe_load(caminho.read_text(encoding="utf-8")) or {} if caminho.exists() else {}
    return {chave(nome): (info or {}) for nome, info in bruto.items()}


def enriquecer_item(item: dict, biblioteca: dict) -> dict:
    item = dict(item)
    info = biblioteca.get(chave(item.get("nome", "")), {})
    item.setdefault("dica", info.get("dica"))
    imagem = item.get("imagem") or info.get("imagem")
    if imagem:
        arquivo = MIDIA / imagem
        if arquivo.exists():
            item["imagem_uri"] = arquivo.resolve().as_uri()
        else:
            print(f"  aviso: imagem não encontrada: {arquivo.relative_to(RAIZ)}", file=sys.stderr)
    video = item.get("video") or info.get("video")
    if video:
        item["video"] = video
        item["qr"] = qr_svg(video)
    return item


def montar_plano(plano: dict, biblioteca: dict) -> dict:
    plano = dict(plano)
    sessoes = []
    for sessao in plano.get("sessoes", []):
        sessao = dict(sessao)
        blocos = []
        for bloco in sessao.get("blocos", []):
            bloco = dict(bloco)
            tipo = bloco.get("tipo", "principal")
            bloco.setdefault("titulo", TITULOS_BLOCO.get(tipo, tipo.capitalize()))
            itens = []
            for item in bloco.get("itens", []):
                if "combinado" in item:
                    itens.append({"combinado": [enriquecer_item(i, biblioteca) for i in item["combinado"]]})
                else:
                    itens.append(enriquecer_item(item, biblioteca))
            bloco["itens"] = itens
            blocos.append(bloco)
        sessao["blocos"] = blocos
        sessoes.append(sessao)
    plano["sessoes"] = sessoes
    return plano


def montar_controle(plano: dict, historico: list[dict]) -> list[dict]:
    """Tabela semana x sessão, marcando o que já foi registrado no histórico."""
    inicio = como_data(plano.get("inicio", dt.date.today()))
    segunda = inicio - dt.timedelta(days=inicio.weekday())
    n_sessoes = len(plano.get("sessoes", []))
    semanas = []
    for s in range(int(plano.get("semanas", 4))):
        ini = segunda + dt.timedelta(weeks=s)
        fim = ini + dt.timedelta(days=6)
        celulas = []
        for n in range(1, n_sessoes + 1):
            feito = next(
                (h for h in historico if h.get("sessao") == n and ini <= como_data(h["data"]) <= fim),
                None,
            )
            celulas.append({"feito": bool(feito), "data": data_br(feito["data"], "dia") if feito else None,
                            "pse": feito.get("pse") if feito else None})
        semanas.append({"numero": s + 1, "inicio": data_br(ini, "dia"), "fim": data_br(fim, "dia"), "celulas": celulas})
    return semanas


def montar_evolucao(historico: list[dict]) -> dict:
    ordenado = sorted(historico, key=lambda h: como_data(h["data"]))

    por_mes = OrderedDict()
    for h in ordenado:
        d = como_data(h["data"])
        rot = f"{MESES[d.month - 1]}/{str(d.year)[2:]}"
        por_mes[rot] = por_mes.get(rot, 0) + 1

    focos = Counter(h.get("foco") or "Outro" for h in ordenado).most_common()

    pse = [(data_br(h["data"], "dia"), float(h["pse"])) for h in ordenado if h.get("pse") is not None]

    cargas: dict[str, list[tuple[str, float]]] = OrderedDict()
    for h in ordenado:
        for nome, kg in (h.get("cargas") or {}).items():
            cargas.setdefault(nome, []).append((data_br(h["data"], "dia"), float(kg)))

    graficos_carga = [
        {"nome": nome, "svg": grafico_linha(pts, " kg")} for nome, pts in cargas.items() if len(pts) >= 2
    ]

    return {
        "total": len(ordenado),
        "ultima": data_br(ordenado[-1]["data"]) if ordenado else "—",
        "meses_ativos": len(por_mes),
        "por_mes": grafico_barras(list(por_mes), list(por_mes.values())),
        "focos": grafico_barras_horizontais([f for f, _ in focos], [c for _, c in focos]),
        "pse": grafico_linha(pse),
        "cargas": graficos_carga,
        "cargas_com_um_registro": [n for n, pts in cargas.items() if len(pts) < 2],
        "recentes": list(reversed(ordenado))[:8],
    }


# ---------- renderização ----------

def css_embutido() -> Markup:
    """Tokens + componentes, com as fontes apontando para arquivos locais."""
    css = (DESIGN / "tokens.css").read_text(encoding="utf-8") + "\n" + (DESIGN / "componentes.css").read_text(encoding="utf-8")
    fontes = (DESIGN / "fontes").resolve().as_uri()
    return Markup(css.replace('url("fontes/', f'url("{fontes}/'))


def renderizar_html(slug: str, ficha: dict, hoje: dt.date) -> str:
    env = Environment(
        loader=FileSystemLoader(RAIZ / "modelos"),
        autoescape=select_autoescape(["html", "j2"]),
        trim_blocks=True,
        lstrip_blocks=True,
    )
    env.filters["data_br"] = data_br
    biblioteca = carregar_biblioteca()
    historico = ficha.get("historico") or []
    plano = montar_plano(ficha["plano"], biblioteca)
    return env.get_template("treino.html.j2").render(
        css=css_embutido(),
        atleta=ficha["atleta"],
        plano=plano,
        controle=montar_controle(plano, historico),
        evolucao=montar_evolucao(historico),
        gerado_em=data_br(hoje),
        slug=slug,
    )


def html_para_pdf(html_path: Path, pdf_path: Path) -> None:
    from playwright.sync_api import sync_playwright

    executavel = os.environ.get("CHROMIUM_PATH")
    with sync_playwright() as p:
        navegador = p.chromium.launch(executable_path=executavel) if executavel else p.chromium.launch()
        pagina = navegador.new_page()
        pagina.goto(html_path.resolve().as_uri(), wait_until="networkidle")
        pagina.evaluate("document.fonts.ready")
        pagina.pdf(path=str(pdf_path), format="A4", print_background=True, prefer_css_page_size=True)
        navegador.close()


def gerar(slug: str, manter_html: bool, hoje: dt.date) -> Path:
    ficha = yaml.safe_load((DADOS / "atletas" / f"{slug}.yaml").read_text(encoding="utf-8"))
    destino = SAIDA / slug
    destino.mkdir(parents=True, exist_ok=True)
    html_path = destino / f"treino-{slug}.html"
    pdf_path = destino / f"{hoje.isoformat()}-treino-{slug}.pdf"
    html_path.write_text(renderizar_html(slug, ficha, hoje), encoding="utf-8")
    html_para_pdf(html_path, pdf_path)
    if not manter_html:
        html_path.unlink()
    return pdf_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("atletas", nargs="*", help="slug do atleta (nome do arquivo sem .yaml)")
    parser.add_argument("--html", action="store_true", help="mantém o HTML ao lado do PDF")
    args = parser.parse_args()

    slugs = args.atletas or sorted(p.stem for p in (DADOS / "atletas").glob("*.yaml"))
    hoje = dt.date.today()
    for slug in slugs:
        print(f"Gerando {slug}...")
        print(f"  -> {gerar(slug, args.html, hoje).relative_to(RAIZ)}")


if __name__ == "__main__":
    main()
