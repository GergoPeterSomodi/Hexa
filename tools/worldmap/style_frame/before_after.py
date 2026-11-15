"""A labelled before | after sheet of two renders, with an optional enlarged crop of both underneath.

python before_after.py OUT.png BEFORE.png AFTER.png "title before" "title after" [PANEL_WIDTH] [x,y,w,h "crop title"]

The crop rectangle is in pixels of the renders; it is enlarged to the panel width.
"""
import os, sys
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame

pygame.init()
BG, FG, SUB = (30, 34, 48), (244, 238, 222), (190, 196, 210)


def sheet(out, before, after, t_before, t_after, pw=1280, crop=None, t_crop=""):
    a, b = pygame.image.load(before), pygame.image.load(after)
    ph = int(a.get_height() * pw / a.get_width())
    head, gap = 54, 12
    rows = 2 if crop else 1
    ch = int(crop[3] * pw / crop[2]) if crop else 0
    img = pygame.Surface((pw * 2 + gap * 3, head + ph + gap + (head + ch + gap if crop else 0)))
    img.fill(BG)
    f = pygame.font.SysFont("segoeui", 22, bold=True)
    for i, (pic, title) in enumerate(((a, t_before), (b, t_after))):
        x = gap + i * (pw + gap)
        pic = pic.convert(24) if pic.get_bitsize() != 24 else pic
        img.blit(pygame.transform.smoothscale(pic, (pw, ph)) if pic.get_width() != pw else pic, (x, head))
        img.blit(f.render(title, True, FG), (x + 4, 12))
        if crop:
            y = head + ph + gap
            part = pic.subsurface(pygame.Rect(crop))
            img.blit(pygame.transform.smoothscale(part, (pw, ch)), (x, y + head))
            img.blit(f.render(t_crop + (", before" if i == 0 else ", after"), True, SUB), (x + 4, y + 12))
            pygame.draw.rect(img, (250, 214, 96), pygame.Rect(crop[0] * pw // pic.get_width() + x, crop[1] * pw // pic.get_width() + head,
                                                             crop[2] * pw // pic.get_width(), crop[3] * pw // pic.get_width()), 1)
    pygame.image.save(img, out)


if __name__ == "__main__":
    a = sys.argv
    pw = int(a[6]) if len(a) > 6 else 1280
    crop = tuple(int(v) for v in a[7].split(",")) if len(a) > 7 else None
    sheet(a[1], a[2], a[3], a[4], a[5], pw, crop, a[8] if len(a) > 8 else "")
