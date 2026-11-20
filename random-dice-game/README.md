# Random Ass Dice Game — içerik ekleme rehberi

Tüm içerik `data/*.json` dosyalarında. Sprite'lar `assets/sprites/` altında.
Kod yazmana gerek yok. Dosyayı kaydet, oyunu yeniden çalıştır (F5).

## Sprite kuralı
`sprite` alanını boş bırakırsan oyun otomatik olarak şunu arar:

| Tür | Dosya |
|---|---|
| Item | `assets/sprites/items/<id>.png` |
| Düşman | `assets/sprites/enemies/<id>.png` |
| Stage arka planı | `assets/sprites/dungeons/<id>.png` |
| Oyuncu | `assets/sprites/players/player.png` |

Farklı bir dosya adı kullanmak istersen: `"sprite": "items/benim_kilic.png"`.
Sprite yoksa oyun yine çalışır, sadece görsel boş kalır. Pixel art keskin görünür (nearest filtre).

## Yeni item — `data/items.json`
```json
{ "id": "fire_sword", "name": "Ateş Kılıcı", "type": "weapon",
  "bonus": 3, "multiplier": 1.2, "dice_count": 1,
  "price": 40, "in_shop": true, "description": "" }
```
- `type`: `weapon` veya `armor`
- `dice_count`: 2 yaparsan Double Dagger gibi çift zar
- `in_shop`: true ise mağazada satılır
- Boss drop yapmak için id'sini bir dungeon'ın `boss_drops` listesine ekle

## Yeni düşman — `data/enemies.json`
```json
{ "id": "rat_swarm", "name": "Fare Sürüsü", "hp": 10,
  "damage_mult": 0.5, "defense": 0, "boss": false }
```

## Yeni stage — `data/dungeons.json`
```json
{ "id": "sewer", "name": "Sewer",
  "crowd": "rat_swarm", "elite": "giant_rat", "boss": "rat_king",
  "boss_drops": ["fire_sword"] }
```
`crowd` zorluk 1-2, `elite` 3-4, `boss` 5-6. Stage sayısı sınırsız, Zar 1 otomatik ona göre atılır.
Tüm boss'ları kesince Boss Yolu açılır; stage sayısı artarsa o da artar.

## Oyuncu ve kurallar — `data/player.json`
Karakter adı, başlangıç can/stamina/altın/iksir/silah/zırh, flee bedeli, mağaza aralığı,
iksir iyileşmesi ve fiyatı, final boss ve ödülü burada. Sprite için `players/player.png`.

## Hata ayıklama
Yanlış id yazarsan (var olmayan düşman/item) Godot'un Output paneline kırmızı hata düşer
ve o stage atlanır.

---

## Item efektleri (`effects`)
Her item `"effects": {...}` alabilir. `type`: `weapon`, `armor`, `rune`, `accessory` (her slottan 1 tane takılır).
Aynı efekt birden fazla itemde varsa toplanır.

| Efekt | Anlamı |
|---|---|
| `lifesteal` | Verilen hasarın bu oranı kadar can çalar (0.2 = %20) |
| `crit` | D20'nin en üst N yüzü kritik (hasar ×2). `crit: 2` → 19-20 |
| `max_hp`, `max_stamina` | Üst sınıra ekler |
| `flee_cost` | Kaçış bedeline ekler (−2 = 2 stamina ucuz) |
| `gold_mult` | Altın çarpanı (0.5 = %50 fazla) |
| `defense_bonus` | Savunma zarına eklenir |
| `hp_regen` | Dungeon sonu iyileşmeye ekler |

Örnek: `{ "id": "x", "name": "Kan Yüzüğü", "type": "accessory", "price": 40, "in_shop": true, "effects": {"lifesteal": 0.25, "max_hp": 3} }`
Rune/aksesuar için bonus/multiplier gerekmez.

## Düşman yetenekleri (`abilities`)
`"abilities": ["heal", "enrage"]` — `heal` (3 turda bir %20 iyileşir), `regen` (her tur +2 can),
`double_hit` (3 turda bir çift saldırı), `pierce` (savunmanı yarıya indirir), `enrage` (canı yarının altına inince hasar ×1.3).

## Denge ayarları (`player.json`)
`depth_hp` / `depth_dmg`: her tamamlanan dungeon düşman canını/hasarını bu oranda artırır (run ilerledikçe zorlaşır).
Mağaza her seferinde `in_shop: true` itemlerden rastgele 4 tanesini gösterir.
