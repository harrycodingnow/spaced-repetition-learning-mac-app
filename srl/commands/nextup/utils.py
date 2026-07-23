from srl.storage import (
    load_json,
    NEXT_UP_FILE,
)


def get_next_up_problems() -> list[tuple[str, str]]:
    """
    returns a list of tuples (name, url)
    """
    data = load_json(NEXT_UP_FILE)
    res = []

    items = list(data.items())
    if any(info.get("order") is not None for _, info in items):
        items = sorted(
            enumerate(items),
            key=lambda indexed: (
                (0, indexed[1][1]["order"], indexed[0])
                if indexed[1][1].get("order") is not None
                else (1, indexed[0], indexed[0])
            ),
        )
        items = [item for _, item in items]

    for name, info in items:
        res.append((name, info.get("url", "")))

    return res
