#!/usr/bin/env python3
"""Assert that every page states its network (specs/NETWORKS.md section 3).

Usage:
    ci/assert-network-label.py <base-url> <testnet|mainnet> [[STATUS:]PATH ...]

Each PATH is fetched without following redirects and must answer STATUS
(default 200). Every page must

  * open with the network ribbon: the first element inside <body>;
  * carry the ribbon's cross-link to the OTHER network's explorer, by its
    explicit hostname, and never link the bare explore.swarm.green;
  * have a <title> that starts with "SWARM Testnet Explorer" or
    "SWARM Mainnet Explorer";
  * show the header chip, on every page that has the header.

On the mainnet, the rest of the page (everything but the ribbon's cross-link,
which is there to say "testnet") must not say "test coins", "no value",
"testnet" or "brs-holding" in any casing. The one allowed "no value" is the
shielded-pool card's "no value pools yet", which is about the node.
"""
import re
import sys
import urllib.error
import urllib.request

EXPLORERS = {
    "testnet": "https://testnet.explore.swarm.green/",
    "mainnet": "https://mainnet.explore.swarm.green/",
}
RIBBON_TEXT = {
    "testnet": "TESTNET</strong> &middot; test coins, no value",
    "mainnet": "<strong>SWARM MAINNET</strong>",
}
TITLE = {
    "testnet": "SWARM Testnet Explorer",
    "mainnet": "SWARM Mainnet Explorer",
}
SWITCH = re.compile(r"<a [^>]*data-network-switch[^>]*>.*?</a>", re.S)
FORBIDDEN_ON_MAINNET = [
    re.compile(r"test coins", re.I),
    re.compile(r"no value(?! pools)", re.I),
    re.compile(r"testnet", re.I),
    re.compile(r"brs-holding", re.I),
]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def fetch(url):
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(url, timeout=60) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", "replace")


def check(base, kind, spec):
    status_text, _, path = spec.partition(":") if re.match(r"^\d{3}:", spec) else ("200", "", spec)
    expected_status = int(status_text)
    other = "mainnet" if kind == "testnet" else "testnet"
    url = base.rstrip("/") + path
    status, html = fetch(url)
    problems = []

    if status != expected_status:
        problems.append(f"expected HTTP {expected_status}, got {status}")

    if not re.search(r'<body>\s*<div class="sw-net-ribbon sw-net-ribbon-' + kind + '"', html):
        problems.append(f"the {kind} ribbon is not the first element of <body>")
    if "sw-net-ribbon-" + other in html:
        problems.append(f"the {other} ribbon is on the page")
    if RIBBON_TEXT[kind] not in html:
        problems.append(f"ribbon text missing: {RIBBON_TEXT[kind]}")

    switches = SWITCH.findall(html)
    if len(switches) != 1:
        problems.append(f"expected one cross-link to the other explorer, found {len(switches)}")
    elif f'href="{EXPLORERS[other]}"' not in switches[0]:
        problems.append(f"the cross-link does not point at {EXPLORERS[other]}: {switches[0]}")
    if "//explore.swarm.green" in html:
        problems.append("the page links the bare explore.swarm.green")

    title = re.search(r"<title[^>]*>([^<]*)</title>", html)
    if not title or not title.group(1).startswith(TITLE[kind]):
        problems.append(f"title does not start with {TITLE[kind]!r}: {title.group(1) if title else None!r}")

    if "<header" in html and f'data-network-chip="{kind}"' not in html:
        problems.append(f"the header has no {kind} chip")

    if kind == "mainnet":
        rest = SWITCH.sub("", html)
        for pattern in FORBIDDEN_ON_MAINNET:
            match = pattern.search(rest)
            if match:
                start = max(match.start() - 80, 0)
                problems.append(f"forbidden wording {pattern.pattern!r}: ...{rest[start:match.end() + 80]!r}...")

    shown = title.group(1) if title else "(no title)"
    if problems:
        print(f"FAIL  {url}")
        for problem in problems:
            print(f"      {problem}")
        return False
    print(f"ok    {url} ({status}, {kind}, title {shown!r})")
    return True


def main(argv):
    if len(argv) < 4 or argv[2] not in EXPLORERS:
        print(__doc__)
        return 2
    base, kind, specs = argv[1], argv[2], argv[3:]
    results = [check(base, kind, spec) for spec in specs]
    if not all(results):
        return 1
    print(f"ok: {len(results)} page(s) state the {kind}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
