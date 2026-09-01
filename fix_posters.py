import urllib.request
import urllib.parse
import re
import json

movies = [
    "SCARFACE", "THE DARK KNIGHT", "HANNIBAL", "THE SHAWSHANK REDEMPTION",
    "THE PERKS OF BEING A WALLFLOWER", "GONE WITH THE WIND", "THE MALTESE FALCON",
    "TOY STORY", "THE TERMINATOR", "DR. NO", "SPIDER-MAN", "IRON MAN",
    "V FOR VENDETTA", "BREAKING BAD", "PEAKY BLINDERS", "JERRY MAGUIRE",
    "HARRY POTTER AND THE DEATHLY HALLOWS PT.2", "BROKEBACK MOUNTAIN",
    "THE NOTEBOOK", "THE SHINING", "CARRIE", "IT", "CAST AWAY",
    "DEAD POETS SOCIETY", "THE HELP", "OM SHANTI OM", "SHOLAY", "WANTED",
    "AIRPLANE!", "THE PRINCESS BRIDE"
]

results = {}
headers = {'User-Agent': 'Mozilla/5.0'}

for title in movies:
    try:
        url = 'https://www.themoviedb.org/search?query=' + urllib.parse.quote(title)
        req = urllib.request.Request(url, headers=headers)
        html = urllib.request.urlopen(req).read().decode('utf-8')
        # Find the first poster path e.g., data-src="/t/p/w94_and_h141_bestv2/qJ2tW6WMUDux911kpUpLlmHGGKB.jpg" or src="..."
        match = re.search(r'/t/p/[a-zA-Z0-9_]+(/[^\"\'\s]+\.jpg)', html)
        if match:
            poster = match.group(1)
            results[title] = f"https://image.tmdb.org/t/p/original{poster}"
            print(f"FOUND {title}: {poster}")
        else:
            print(f"NOT FOUND {title}")
    except Exception as e:
        print(f"ERROR {title}: {e}")

with open('posters_fix.json', 'w') as f:
    json.dump(results, f, indent=2)
