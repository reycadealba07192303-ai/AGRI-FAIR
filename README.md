# AgriFair

Isang palengke ng bigas na nag-uugnay sa magsasaka at mamimili nang walang
namamagitan. Capstone project.

Tatlong bahagi ang sistema:

| Bahagi | Teknolohiya | Para kanino |
|---|---|---|
| `backend/` | Node, Express, MongoDB, Firebase Auth | Pinagsasaluhan ng dalawa |
| `frontend/` | React, Vite | Seller, admin, superadmin |
| `mobile/` | Flutter | Buyer |

Ang web ay ang dashboard ng nagbebenta at namamahala. Ang mobile ay ang tindahan
ng bumibili. Iisa ang API na kinakain nila — nakasulat sa
[API_CONTRACT.md](API_CONTRACT.md) ang eksaktong hugis ng bawat sagot.

Ang plano ng pagkonekta ay nasa [phases.md](phases.md).

---

## Pagpapatakbo

Kailangan: Node 18+, MongoDB, Flutter 3.41+, at isang Firebase project.

### Backend

```bash
cd backend
npm install
cp .env.example .env    # punan (tingnan sa ibaba)
npm run dev             # http://localhost:8080
```

### Web

```bash
cd frontend
npm install
npm run dev             # http://localhost:5173
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

Ang `localhost` sa cellphone ay ang cellphone mismo, hindi ang laptop mo. Kaya:

- **Android emulator** — `http://10.0.2.2:8080`, ito na ang default
- **Totoong cellphone, USB** — pinakamaaasahan, at hindi alintana ang network:

```bash
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=USE_ADB=true
```

  Idinadaan nito sa cable ang sariling `localhost:8080` ng cellphone papunta sa
  laptop. Gumagana kahit magkaibang network kayo — mobile data, ibang Wi-Fi, o
  wala man. Kailangan lang ay nakabukas ang USB debugging at nakasaksak ang
  cable. **Uulitin ang `adb reverse` sa tuwing tatanggalin at isasaksak ulit
  ang cable**, o kapag nag-restart ang adb.

- **Totoong cellphone, Wi-Fi** — magkaparehong network kayo:

```bash
flutter run --dart-define=USE_LAN=true
```

Ang address ay nasa `lanHost` sa `lib/services/api_config.dart`. Galing ito sa
DHCP, kaya nagbabago kapag nag-reconnect ang laptop — kapag bigla nang hindi
maabot ang server, dyan ka unang tumingin (`ipconfig`, tingnan ang IPv4 ng
Wi-Fi adapter). Kapag nagpalit, **dalawa** ang inaayos: ang `lanHost` at ang
`android/app/src/main/res/xml/network_security_config.xml`.

Puwede ring buong URL nang hindi ginagalaw ang code:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.14:8080/api
```

---

## Mga kailangang ilagay sa `.env`

Kopyahin ang `backend/.env.example`. Ito ang mga hindi kusang gumagana:

| Susi | Saan kukunin |
|---|---|
| `MONGODB_URI` | Sarili mong MongoDB |
| `JWT_SECRET` | Kahit anong mahabang random na teksto |
| `FIREBASE_CREDENTIALS_PATH` | Service account JSON mula sa Firebase Console, Project settings, Service accounts |
| `FIREBASE_WEB_API_KEY` | Firebase Console, Project settings, General |
| `SMTP_USER`, `SMTP_PASS` | Para sa OTP. Sa Gmail, **App Password** ito, hindi ang password ng account mo |

> Walang naka-commit na credential dito. Ang service account key at ang `.env`
> ay naka-ignore, at kailangan mong ilagay ang sarili mo.

---

## Mga bagay na madaling ikagulat

**Iisa ang pinanggagalingan ng password, dalawa ang nagtatago.** Ang Firebase ang
sinusuri ng login; ang bcrypt hash sa Mongo ay pamalit lang kapag hindi maabot
ang Google. Kaya ang bawat pagpapalit ng password ay **kailangang magsulat sa
dalawa** — kung isa lang, makakapasok pa rin ang lumang password.

**Iba ang verification ng web at mobile.** Nakabatay sa `x-client` header:

| Client | Natatanggap |
|---|---|
| `x-client: mobile` | 6 na digit sa email, dala ng nodemailer |
| lahat ng iba | Firebase verification link |

May anim na kahon ang cellphone at walang mabubuksang link nang hindi lumalabas
ng app; may pahina ang web at walang kahon para sa code. Bawat isa ay
binibigyan ng kaya niyang tapusin.

**Kailangang magpadala ng `role: 'buyer'` ang mobile sa pag-register.** Kapag
wala, `seller` ang babagsakan ng backend — at ang seller ay naghihintay ng
approval bago makapasok. Tahimik na magiging naka-lock ang bawat signup.

**`variety` ang tawag sa uri ng bigas, hindi `category`.** Tinatanggap pa rin
ang `category` bilang query alias.

**Ang README na ito ay UTF-8.** Ang `echo "..." >> README.md` sa PowerShell ay
nagsusulat ng UTF-16 at sinisira ang mga naunang titik. Gumamit ng editor, o
ng `Out-File -Encoding utf8`.

---

## Istraktura

```
backend/src/
  routes/         → controllers/  → services/     → repositories/
  models/         mongoose schemas
  config/         firebase, mailer
  middleware/     auth, rate limits, uploads
  scripts/        one-shot migrations

frontend/src/
  pages/          landing, admin, superadmin
  services/       axios, may Bearer interceptor

mobile/lib/
  screens/        buyer screens
  services/       api_client, auth_service, product_service, seller_service
  models/         Product, SellerProfile, ChangeNotifier state
  widgets/        clay.dart — ang claymorphism design system
  theme/          app_theme.dart — kulay, radius, anino, font
```

---

## Pagsubok

```bash
cd mobile
flutter test
```

Ang ilang test ay kumakausap sa **tunay na backend** — sinadya iyon. Ang
tanong na sinasagot nila ("tama ba ang pagkakakonekta") ay hindi kayang sagutin
ng mocked na test. Nakasulat sa itaas ng bawat file kung ano ang kailangan
bago ito patakbuhin.
