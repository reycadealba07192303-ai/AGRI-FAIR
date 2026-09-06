# AgriFair — Pagkonekta ng Mobile at Web sa Backend

Siyam na phase, sunod-sunod. Konektado na ang web; ang mobile ay UI pa lang.
Ang backend ang pinagsasaluhan nilang gitna — doon tayo magsisimula.

- **Repo:** Josh-Mrzn/Captone-Project
- **Branch:** `rendays-backend-orders`
- **Petsa:** Set 3, 2026

---

## Nasaan tayo ngayon

Tatlong bahagi, magkaibang antas ng pagkakatapos. Mahalagang makita ito bago tayo
kumilos — dito nakasalalay ang pagkakasunod-sunod ng mga phase.

### Backend — gumagana

Labing-isang route group, buhay. Pero ang mga buyer endpoint ay **walang gumagamit** —
walang client na tumatawag sa kanila.

- `/api/cart` — 0 consumers
- `/api/buyer/orders` — 0 consumers
- `/api/reviews` — 0 consumers

### Web (React) — konektado

Axios instance, Bearer interceptor, token sa `sessionStorage`
(`frontend/src/services/authApi.jsx`). Tapos na ang seller, admin, at superadmin
dashboards.

- walang buyer storefront
- `ForgotPasswordPage.jsx` = pekeng `setTimeout`, walang tinatawag na API

### Mobile (Flutter) — hindi konektado

Dalawampung screen, maganda ang UI — pero **walang kahit anong network code**.
Puro hardcoded na mock data.

- walang `http` / `dio` package
- walang `lib/services/`
- walang URL sa buong `lib/`

> **Tandaan:** malinis pala ang hatian — ang web ay para sa seller/admin/superadmin,
> ang mobile ay para sa buyer. Kaya walang tumatawag sa buyer endpoints: hindi sila
> patay na code, wala pa lang client. Ang mobile app ang hinihintay nila.

---

## ✅ Naipush na

Nasa GitHub na ang lahat sa branch na `rendays-backend-orders`, kasama ang buong
Flutter app at ang history ni Josh. Ang natitira na lang ay ang pull request
papuntang `main`.

---

## Ang siyam na phase

Sunod-sunod ito, hindi basta listahan. May kinakailangan ang bawat phase mula sa
nauna, at may malinaw na palatandaan kung kailan ito tapos.

### Phase 0 — Ayusin ang access sa repo
`Repo`

Walang saysay ang lahat ng susunod kung hindi makakapasok sa repo ang trabaho.

- [x] Padagdag kay Josh bilang collaborator (Settings → Collaborators)
- [x] Tingnan kung tamang GitHub account ang naka-login sa git — `reycadealba07192303-ai` ang tumatawag ngayon
- [x] I-push ang branch — naipush bilang `rendays-backend-orders`
      (may branch nang `rendays` sa remote, kaya hindi puwede ang `rendays/backend-orders`: magkasalungat ang ref path)
- [ ] Gumawa ng pull request papuntang `main`

**Tapos kapag:** nakikita na ng buong grupo ang `mobile/` sa GitHub.

---

### Phase 1 — Isang kontrata para sa dalawang client
`Backend` `Mobile` `Web`

Dalawang client ang kakain sa iisang API. Kapag hindi natin pinagkasunduan ang hugis
ng data ngayon, dalawang beses nating aayusin mamaya.

- [x] Pumili ng iisang pangalan: `variety` (backend) o `category` (mobile)
- [x] Ilabas ang `averageRating` sa product response, kinuha mula sa Review model
- [x] Desisyunan ang `soldCount` at `tag` — wala ang mga ito sa Product model
- [x] Isulat ang eksaktong response shape ng `GET /api/products/:id` bilang sanggunian ng dalawa — [API_CONTRACT.md](API_CONTRACT.md)

**Tapos kapag:** may nakasulat na kontrata na kayang sundin ng mobile at web nang
hindi nagtatanong.

---

### Phase 2 — Tubero ng mobile
`Mobile`

Ang layunin dito ay isang matagumpay na request — kahit isa lang. Doon mapapatunayan
na kayang abutin ng app ang server mo.

- [x] Idagdag sa `pubspec.yaml`: `http`, `flutter_secure_storage`, `provider`, `cached_network_image`, `intl`
- [x] Gawin ang `lib/services/api_client.dart` — base URL at awtomatikong `Authorization: Bearer`
- [x] Ilipat ang `INTERNET` permission sa `main/AndroidManifest.xml` — nasa `debug/` lang ito ngayon, kaya patay ang release build
- [x] Magdagdag ng network security config para sa `http://` habang dev — hinaharangan ito ng Android 9 pataas
- [x] Base URL: `10.0.2.2:8080` sa emulator, LAN IP sa totoong telepono

**Tapos kapag:** may isang screen na kumukuha ng totoong `GET /api/products` at
nakikita ang laman ng database.

---

### Phase 3 — Auth sa mobile
`Backend` `Mobile`

Ang backend ang nag-iisyu ng sarili nitong JWT; ang Firebase ay para lang sa password.
**Ang backend JWT ang itatago** — hindi ang `firebaseIdToken`.

- [x] Ikabit ang Sign In at Sign Up sa `/api/auth/login` at `/api/auth/register`
- [x] Itago ang token sa `flutter_secure_storage`, hindi sa SharedPreferences
- [x] Auth state na kayang basahin ng buong app, at auto-logout kapag 401

**Tapos kapag:** nakapag-login ka sa mobile gamit ang account na ginawa mo sa web.

---

### Phase 4 — Isulat muli ang models
`Mobile`

Ito ang pinakamabigat na phase, at hinaharangan nito ang lahat ng natitira. Hindi
kayang gawing JSON model ang `RiceProduct` sa kasalukuyang anyo nito.

- [ ] Dagdagan ng `id` ang lahat ng model — wala nito ngayon, at kailangan ito ng bawat endpoint
- [ ] Alisin ang `Color` at `IconData` sa loob ng models — hindi galing sa JSON ang mga iyon
- [ ] Palitan ang `const riceProducts` ng async fetch; gawing async ang mga screen na umaasa dito
- [ ] Kunin ang weight pricing sa `weightTiers` ng backend — huwag nang i-compute sa app

**Tapos kapag:** wala nang kahit isang hardcoded na produkto sa `lib/models/`.

---

### Phase 5 — Katalogo
`Backend` `Mobile`

Dito unang magkikita ang dalawang panig: ang inilagay ng seller sa web ay lalabas sa
telepono ng buyer.

- [ ] Home at Product Detail mula sa `/api/products` at `/api/products/:id`
- [ ] Search at category filter — `/search`, `/category/:category`
- [ ] Mga larawan mula sa backend URLs, hindi na local assets
- [ ] Product Reviews (pagbasa lang) mula sa `/api/reviews/product/:id`

**Tapos kapag:** ang produktong idinagdag mo sa web admin ay lumalabas sa mobile nang
walang rebuild.

---

### Phase 6 — Cart at checkout
`Backend` `Mobile`

Unang pagkakataong magsusulat ang mobile sa database, hindi lang magbabasa. Dito
unang gagalaw ang stock.

- [ ] Cart screen sa `/api/cart` — dagdag, bawas, at tanggal ng item
- [ ] Checkout papuntang `POST /api/cart/checkout`
- [ ] Order Success mula sa totoong sagot ng server, hindi sa mock

**Tapos kapag:** ang order mula sa telepono ay lumalabas sa admin dashboard sa web,
at bumaba ang stock.

---

### Phase 7 — Orders, reviews, notifications, chat
`Backend` `Mobile` `Web`

Ang natitirang mga screen. Dito nagiging dalawahang-daan ang usapan ng buyer at seller.

- [ ] Ongoing Orders, Order History, Order Detail — `/api/buyer/orders`
- [ ] Write Review — `POST /api/reviews`
- [ ] Notifications — `/api/notifications`, kasama ang pagmarka ng nabasa
- [ ] Chat — `/api/chat/conversations`, `/messages/:id`, `/send`
- [ ] Profile at Edit Profile — `/api/user/me`, `/api/user/edit`

**Tapos kapag:** ang sagot ng seller sa web chat ay dumarating sa mobile ng buyer.

---

### Phase 8 — Habol ng web at paghahanda sa release
`Mobile` `Web`

Ang mga natirang butas, kabilang ang isang pekeng screen sa web na madaling
makalimutan hanggang sa defense.

- [ ] Totohanin ang `ForgotPasswordPage.jsx` sa **web** — `setTimeout` lang ito ngayon, walang tinatawag na API
      (tapos na ang mobile: forgot password, OTP, at change password)
- [ ] Ipatupad sa dalawang client ang napagkasunduan sa Phase 1 tungkol sa forgot password at OTP
- [ ] Ayusin ang Firebase package: `AgriFair.com` ang nakarehistro, `com.example.mobile_app` ang app
- [ ] Palitan ang pangalan ng app mula sa template na `mobile_app`
- [ ] Lumipat sa HTTPS at alisin ang cleartext config bago mag-release build

**Tapos kapag:** tumatakbo ang release APK laban sa naka-deploy na backend, walang
naiwang pekeng screen.

---

## Dalawang desisyon bago ang Phase 2

Hindi ito puwedeng hulaan — nakaapekto sa dalawang client at sa hugis ng database.
Sagutin habang nasa Phase 1 pa.

### 01 — Idadagdag ba sa backend ang `soldCount` at `tag`, o tatanggalin sa UI?

Ipinapakita ng mobile ang bilang ng nabenta at mga badge tulad ng "Best Seller".
Walang ganitong field ang Product model sa backend.

- Dagdagan ang Product ng `soldCount`, itaas tuwing may checkout
- Tanggalin sa UI at gawing pandekorasyon na lang ang badge

### 02 — Paano ang forgot password at OTP? ✅ NAPAGDESISYUNAN

**Sariling endpoint sa backend, gamit ang nodemailer.** Iisang flow para sa web at
mobile, at tugma sa `otp_verification_screen.dart` na meron na.

Tapos na at nasubukan:

- `POST /api/auth/forgot-password` — `{ email }`, magpapadala ng 6-digit code
- `POST /api/auth/verify-reset-otp` — `{ email, code }` → `resetToken`
- `POST /api/auth/reset-password` — `{ resetToken, newPassword }`

---

## Puwedeng sabay-sabay

Ang Phase 2 hanggang 7 ay iisang linya ng trabaho sa mobile — sunod-sunod, at mahirap
paghatian. Pero ang trabaho sa web sa Phase 8, pati ang mga pagbabago sa backend mula
sa Phase 1, ay kayang tapusin ng ibang kagrupo nang hindi hinihintay ang mobile.
Doon kayo maghati.
