# AgriFair — Ano na ang naayos

Talaan ng mga natapos, ayon sa bahagi ng system. Ang mga bug ay isinulat kasama
ang **dahilan**, hindi lang ang sintomas — iyon ang bahaging mahirap balikan
pagkalipas ng ilang buwan.

Para sa kung paano magkakadikit ang lahat: [ARCHITECTURE.md](ARCHITECTURE.md).
Para sa orihinal na plano: [phases.md](phases.md).

- **Huling na-update:** Set 8, 2026

---

## Auth at seguridad

| Ano | Estado |
|---|---|
| OTP sa pag-signup ng mobile (nodemailer) | ✅ |
| OTP sa pag-reset ng password | ✅ |
| Firebase verification link para sa web | ✅ |
| Bawal ang dobleng pangalan at email | ✅ |
| Hindi magagamit ang account bago ma-verify | ✅ |

**Isang code engine, dalawang gamit.** Pinagsama ang `PasswordResetOtp` at ang
signup OTP sa iisang `EmailOtp` na pinaghihiwalay ng `purpose`. Ang hash lang ang
iniimbak, may TTL index, at `crypto.randomInt` ang gamit — hindi `Math.random`.

**Ang password ay nasa Firebase, hindi sa Mongo.** Nagbabago lang ang Mongo hash
bilang offline fallback. May bug dito: nagsusulat lang sa Mongo ang
`updatePasswordService`, kaya tumatanggap pa rin ang login ng **lumang password**
— Firebase kasi ang tinitingnan ng login. Ngayon, sa Firebase muna bago sa Mongo.

**Nakahiwalay na ang mga rate limiter.** Dati ay iisa ang limiter para sa buong
OTP flow, kaya limang request lang ang buong proseso. Tatlo na ngayon
(`password`, `otpRequest`, `otpSubmit`), at **JSON** ang lahat ng 429 — dating
plain text, kaya dumarating ito sa app bilang "Unexpected server response".

**Hindi na humahawak ng login failure ang global 401 handler.** Kapag walang
token na ipinadala, ang 401 ay *ang* pag-login mismo, hindi nawalang session.
Dati nitong nililinis ang nav stack bago pa mapakita ang OTP screen.

---

## Mga error at pagganap

**Walang Express error handler noon.** Ang bawat hindi nahuling error ay
nagpapadala ng HTML page na may buong stack trace at absolutong path ng laptop.
Mayroon nang `errorMiddleware.js`: `notFoundHandler` + `errorHandler`, na
nagsasalin ng CastError→404, ValidationError→400, 11000→409, JWT→401. Walang
stack sa production.

**Anim na segundo ang OTP endpoints.** Hinihintay ng request ang SMTP. Ngayon ay
fire-and-forget na ang pagpapadala, at may connection pooling ang mailer:

| Endpoint | Dati | Ngayon |
|---|---|---|
| Resend OTP | 5.4s | 1.5s |
| Register | 6.2s | 2.0s |

---

## Cart at checkout

**Bawat timbang ay hiwalay na linya.** Ang parehong bigas sa 25 kg at 50 kg ay
dalawang linya, dahil dalawa itong magkaibang pagbili sa magkaibang presyo bawat
kilo. Nagdagdag ng `weightKg` sa `Cart`, at `quantity` ay **bilang ng sako**,
hindi kilo.

**Nasa server na ang cart.** Dati ay nasa memorya lang ng app — kaya laging
walang laman ang nakikita ng checkout, at nawawala ang cart sa reinstall.

**"Your cart is empty" habang may laman.** Dalawang magkapatong na dahilan:
isang beses lang binabasa ang cart (sa sign-in, tahimik kapag pumalya), at
magkamukha ang "hindi pa nababasa" at "walang laman". Ngayon: nagre-refresh sa
tuwing bubuksan, may skeleton habang naghihintay, at **Try again** kapag
nag-fail. Alam na ng `CartModel` kung sumagot na ba talaga ang server
(`isLoaded`).

**Nagba-crash ang `cartRepository.clear`.** Nagbabalik ito ng `null` para sa
cart na hindi pa nalilikha, at binabasa ng caller ang `.items` nito. Upsert na
ngayon.

**Address book at bayad.** May default na address, pwedeng magdagdag ng bago.
GCash (QR at numero ng seller, tapos i-upload ang resibo) at Cash on Delivery.
Province → Municipality → Barangay, sunod-sunod na dropdown mula sa tunay na
PSGC.

---

## Produkto

**Nawawala na ang naubos.** Isang tuntunin sa isang lugar —
`STOREFRONT_FILTER` sa `models/Product.js` — na sinusunod ng listing, search,
category, shop ng seller, at ang shop directory. Napatunayan sa buhay na server:

| | stock 10 | stock 0 |
|---|---|---|
| listing · shop · search · category | nakikita | **wala na** |
| shop directory | may laman | walang laman na tindahan |
| seller (`?includeSoldOut=true`) | nakikita | **nakikita pa rin** |

Sadya ang huling hilera: kailangang makita ng seller ang naubos para ma-restock.

**Nasa Add to Cart at Buy Now na ang pagpili ng timbang.** Wala nang presyo at
dami sa mismong product page — tungkol na ito sa bigas, at ang sheet ang tungkol
sa pagbili. Lumalabas ang **lahat** ng karaniwang sukat sa Pilipinas
(1, 2, 5, 10, 25, 50 kg), at ang hindi mabibili ay **hindi mapipindot**, na may
sinasabing dahilan.

Dalawang magkaibang dahilan kung bakit hindi mabibili ang isang sukat, at
magkaiba ang kailangang sabihin:

- Hindi ito tinitinda ng seller.
- Tinitinda niya, pero kulang na ang natitira — 10 kg na lang, kaya hindi na
  kayang punan ang 25 kg o 50 kg.

Ang pangalawa ang eksaktong lumabas sa screenshot: mapipindot ang 25 kg at
50 kg gayong 10 kg na lang ang stock, at pagkatapos lang malalaman ng buyer.

**`category` laban sa `variety`.** Ang filter ay tumitingin sa field na wala sa
schema, kaya tahimik itong walang tinatama. Tinatanggap na ngayon ang dalawa.

---

## Mga mensahe

**Kausap ng seller ang sarili niya sa web.** Ang `otherParticipant` ay
naghahanap ng `user.userId`, pero `id` ang pangalan nito sa ibinabalik ng
`/auth/login` — kaya `undefined` iyon, walang natugmang "hindi ako", at
napupunta sa `participants[0]`: ang seller mismo. Lahat ng mensahe ay lumalabas
sa iisang panig, at ang sagot ay papunta sa kanya rin.

Kaparehong ugat ng bug sa mobile, ibang kliyente lang. Dalawang pag-aayos:

1. Ibinabalik na rin ng `/auth/login` ang `userId` sa tabi ng `id`, kaya iisa na
   ang pangalan nito sa buong API.
2. **Tinatanggihan na ng server ang pagme-message sa sarili.** Hindi ito
   pagpapaganda: ang kliyenteng hindi makatukoy kung sino ang kabila ay
   babagsak sa unang participant — ang sarili nito. Ang pagtanggi ay ginagawang
   nakikitang error ang tahimik na pagkakamali.

**Hindi lumalabas ang kausap sa mobile.** Ang tabs ay nasa `IndexedStack`, na gumagawa ng
lahat ng screen sa simula at hindi na muli. Isang beses lang tumatakbo ang
`initState` ng Messages — **noong binuksan ang app**, bago pa may kausap. Ngayon
ay muling binabasa ito kapag pinindot ang tab.

**Lahat ng mensahe ay mukhang galing sa kabila.** Dalawang antas ito:

1. Pinaghahambing ang numeric `userId` sa Mongo `_id`. Hindi magtutugma iyon
   kailanman, at walang error na lalabas.
2. Ang mas malalim na pinagmulan: **numeric** ang `id` na ibinabalik ng
   `/auth/login`, pero **Mongo `_id`** ang nababasa mula sa `/user/me`. Ibig
   sabihin, tama ang chat pagkatapos mag-login at **mali pagkatapos i-restart ang
   app**. Isang pagkakakilanlan na lang ngayon: `userId` muna, laging.

**May unread count na.** Isang `$group` aggregate para sa buong inbox, hindi
isang bilang bawat hilera. Nalilinis ito sa pagbukas ng usapan — dati ay
walang naglilinis, kaya wala na itong kahulugan.

**Nagsasalita na ang order sa usapan.** Kapag may inorder, kinumpirma, ipinadala,
o kinansela, may nakasulat na sa mismong thread — hindi lang sa notification na
nasa-scroll palayo. Napatunayan mula sa unang hanggang huling hakbang:

```
* Order AGF-D77AA2 placed - 1x Premium Jasmine Rice (Copy) (25 kg).
  Total P1470.00, paid by Cash/COD. Waiting for the seller to confirm.
* Order AGF-D77AA2 is confirmed. The seller is preparing it now.
* Order AGF-D77AA2 is being packed.
* Order AGF-D77AA2 is on the way. Please keep your phone reachable for the rider.
```

Hindi kailanman unread ang mga ito. Ang order na napunta sa "shipped" ay balita,
hindi tanong — hindi ito dapat maglagay ng pulang badge.

**May Send product na.** Mapipili mula sa mga listing ng shop, at dumarating ito
bilang card na may pangalan, presyo, at natitirang stock — mapipindot papunta sa
buong produkto. Ang tanong na "meron pa po ba nito?" ay may itinuturo na ngayon.

---

## Bayad at approval

**May UI na ang Super Admin para sa credentials.** Buo na ang backend
(`/superadmin/credentials/pending` at `/users/:id/credentials`) pero **walang
tumatawag dito** — kaya nakabinbin ang GCash mo nang walang paraan para
aprubahan. May bagong **Credentials** tab na sa Super Admin: makikita ang
account name, numero, at QR, at pwedeng aprubahan o tanggihan (kailangan ng
dahilan ang pagtanggi).

Hanggang maaprubahan, **walang ipinapadala ang server** — walang numero, walang
QR. Ang QR na hindi pa natitingnan ay pwedeng magpadala ng pera kahit saan.

**Blangkong kahon ang lumalabas sa GCash.** Ang `??` ay pumapalya lang sa
`null`, hindi sa walang lamang teksto:

```dart
payment?.reason ?? 'This seller has not set up online payment yet.'
```

Kapag `''` ang `reason`, `''` pa rin ang resulta — kaya blangkong kulay-abong
kahon ang nakikita, na walang paliwanag.

**Mali rin ang mensahe.** "Hindi pa nag-set up ng online payment" ang sinasabi
nito sa seller na **nag-submit na** at naghihintay lang ng Super Admin. Ngayon
ay sinasabi kung alin sa tatlo: hindi pa naka-set up, naghihintay ng approval,
o hindi inaprubahan.

**Sa server na ipinapatupad ang resibo ng GCash.** Naka-disable na ang Place
Order button kung walang resibo, pero ang button ay kagandahang-loob lang —
kahit ano ay pwedeng mag-post sa endpoint. Ang seller na iniwang walang
mapatunayang GCash order ang magbabayad para doon.

---

## Mga larawan sa likod ng auth

**Ang may-ari lang ang makakabasa ng file.** Iyon ang panuntunan dati sa
`/api/files`, at iyon ang dahilan ng tatlong blangkong kahon nang sabay-sabay:

- Hindi makita ng **buyer** ang **QR ng seller** — 403, kaya walang mai-scan.
- Hindi makita ng **seller** ang **resibo ng buyer** — wala man lang ito sa
  listahan ng pinapayagan, kaya superadmin lang ang makakabukas.
- Hindi makita ng **buyer** ang **sarili niyang resibo**.

Tatlong dagdag na tuntunin ngayon, at bawat isa ay may dahilan:

| Sino | Ano | Bakit |
|---|---|---|
| May-ari | Sariling QR at dokumento | Kanya iyon |
| Kahit sinong naka-sign in | **Aprubadong** QR ng seller | Iyon ang pambayad — dapat makita |
| Buyer at seller ng order | Ang resibo ng order na iyon | Dalawa lang ang may kinalaman doon |
| Super Admin | Lahat | Siya ang nagre-review |

Napatunayan: nakakabasa ang buyer ng aprubadong QR (200), tinatanggihan ang
resibo ng ibang tao (403), at 401 kapag walang token. Hindi naililibre ang
hindi pa aprubadong QR — credential pa rin iyon hangga't walang tumitingin.

**Hindi gumagana ang `<a href>` sa mga file na ito.** Ang "View the buyer's
proof of payment" ay plain link papunta sa `/api/files/...` — walang
Authorization header ang browser navigation, kaya 403 at blangkong tab. Naka-
**modal** na ito ngayon: kinukuha bilang blob sa parehong axios instance na may
token, at bumubukas kung saan ginagawa ang desisyon — hindi sa ibang tab.

Isang `PrivateImage` widget na lang sa mobile (nabubuksan nang malaki — binabasa
ang resibo, hindi sinusulyapan; ini-scan ang QR mula sa ibang telepono).

**Nakalagay na ang larawan sa chat ng web.** Nakasulat lang dating "Photo
attached" — akin ang pagkakamaling iyon.

**Hindi na nawawala ang naaprubahan sa Super Admin.** Ang desisyong naglalaho
paglabas pa lang ay hindi na matitingnan muli, at ang QR na lumabas na sa iba
ang may-ari ay dapat mabawi. Nakikita na ngayon ang lahat, may badge kung ano
ang naging pasya, at nasa itaas ang naghihintay.

---

## Sako laban sa kilo

**Isang sakong 25 kg ay nagbabawas ng isang kilo lang.** Nakita sa Stock
History: `Sale −1 kg` para sa order na 25 kg.

Kilo ang yunit ng `stock`, pero **sako** ang bilang ng `quantity` sa order — at
direktang ibinabawas ang sako sa kilo. Walang error, walang babala; tumpak na
mali lang ang mga numero.

Alam na ito ng cart (`weight × sacks` ang sinusuri nito laban sa stock), pero
hindi naitatala ng order ang laki ng sako — nasa **pangalan** lang ito bilang
teksto: `"Premium Jasmine Rice (25 kg)"`.

Ngayon ay may `weightKg` na ang bawat order line, at may isang lugar na
nagsasabi kung ilang kilo ang umaalis sa istante:

```js
export const stockUnits = (order) =>
  Number(order?.quantity || 0) * Number(order?.weightKg || 1);
```

Dumadaan dito ang lahat ng gumagalaw ng stock. Nananatiling **sako** ang
`soldCount` — ang "8 sold" ay walong sako, hindi walong kilo.

Napatunayan: `node src/scripts/checkStockUnits.js`

```
order   AGF-2F0EA6: 1 x 50 kg
confirm 442 kg  ->  50 kg left the shelf, expected 50
cancel  492 kg  ->  back to where it started
  OK  kilograms leave the shelf, not sacks
  OK  sold count moves by sacks
  OK  cancelling returns exactly what it took
```

May migration para sa mga luma: `node src/scripts/backfillOrderWeights.js` —
kinukuha ang laki mula sa pangalan. Napatakbo na: **61 order line**. Mahalaga
ito lalo sa mga hindi pa nakukumpirma; ang pagkumpirma ng walang `weightKg` ay
maling bawas ulit.

**Hindi ko itinama ang stock na naibawas na.** Ang mga nakumpirma nang order ay
kumuha ng **267 kg na kulang**. Desisyon iyon ng nagbibilang ng tunay na sako,
hindi ng script — iniuulat lang nito at iniiwan. Ayusin sa Inventory kung hindi
tugma sa aktwal.

---

## Mga naghahatid

**Bagong role: `rider`.** Hindi sila nagsa-sign up — idinadagdag sila ng seller
na pinagtatrabahuhan nila.

```
Seller: pangalan + email  ->  account (random password na walang nakakaalam)
                          ->  6-digit code sa email

Rider sa sign-in (app at web): "Signing in as a delivery rider?"
  1. email lang        ->  may account ba? -> ipinapadala ang code
  2. gumawa ng password
  3. i-verify gamit ang code  ->  pwede nang mag-sign in
```

**Email muna bago lahat.** Tinitingnan kung may account bago pa may hingiin na
kahit ano — ang rider na namali ng type sa email na ibinigay ng shop niya ay
dapat masabihan, hindi iwang naghihintay ng email na hindi naman darating.

Sinasabi ito nang tapat kung may account nga: **sadyang kaiba** ito sa
forgot-password, na hindi nagsasabi kung rehistrado ang isang email. Ang
napapala ng nag-uusisa ay maliit — walang password ang account na iyon na alam
ninuman, at kailangan pa rin nila ang code sa mismong mailbox. Naka-rate limit
ito gaya ng lahat ng humihingi ng code.

**Hawak muna ang password hanggang tumama ang code.** Isang tawag lang ang
nagse-set nito, kaya ang hindi natapos na pagsubok ay walang naiiwan.

**Hindi kailanman nalalaman ng seller ang password.** Random ito at itinatapon
— hindi dapat kayang mag-sign in ng seller bilang tauhan niya. Ang rider ang
pumipili nito sa `/activate`, kapareho ng OTP na natatanggap ng lahat.

Tinatanggihan ang pag-sign in bago ma-activate, at **sinasabi kung bakit**:
`ACCOUNT_NOT_ACTIVATED`, hindi "Invalid credentials" — totoo iyon pero walang
silbi.

**Ang pag-assign ang nagbubukas ng order, hindi ang pagtatrabaho.** Ang rider
ay nakakakita lang ng order na nakapangalan sa kanya. Ang naghahatid para sa
isang tindahan ay walang dapat makita sa ibang tindahan.

| Sino | Ano ang kaya |
|---|---|
| Seller | Magdagdag, mag-resend ng code, mag-suspend, mag-assign kada order |
| Rider | Makita ang naka-assign, mag-share ng posisyon, mag-upload ng patunay |

**Nasa mobile app na rin ang rider.** May sariling screen na siya
(`RiderHomeScreen`): listahan ng ihahatid, kung saan kukunin at saan dadalhin,
tawag sa buyer, kung may kokolektahing cash, at kamera para sa patunay.

Dati, pagkatapos mag-sign in ay **palaging `MainScreen`** ang binubuksan
anuman ang role — kaya ang delivery rider ay pinapakitaan ng bigas na bibilhin.
May cart pa nga siya. Ruta na ngayon ayon sa role, pati sa nasasauling session.

Nandiyan pa rin ang portal sa web (`/rider`) para sa riders na mas gusto ang
browser, pero ang app na ang pangunahin.

**Live ang posisyon habang naka-on ang sharing.** `watchPosition`, ipinapadala
tuwing 15 segundo — mas madalas mag-ulat ang telepono kaysa gumalaw ang
delivery, at 15 segundo rin ang polling ng mapa ng buyer. Kumukurap ang
pindutan habang naka-on, dahil ang nakalimutang naka-on ay ubos na baterya.

**Kada order row ang patunay ng paghahatid**, hindi kada basket — dalawang sako
mula sa dalawang seller ay dalawang biyahe, at kailangang mapatunayan ang bawat
isa nang hiwalay. Pribado ang litrato: nandoon ang pintuan at gate ng buyer.
Tatlong tao lang ang nakakakita — ang buyer, ang seller, at ang rider.

Ang pag-upload ng patunay ay **naglalagay din ng "delivered"** sa order.
Iisang pangyayari iyon; ang paghiwalayin ang dalawa ay kung paano nagkakaroon
ng order na "delivered" na walang maipakita.

Napatunayan mula sa una hanggang huli:
`node src/scripts/checkRiderFlow.js` — sampung hakbang, mula sa pagdagdag ng
seller hanggang sa makita ng buyer ang litrato.

**Sinu-suspend, hindi binubura.** Nakapangalan sila sa mga naihatid na order,
at ang pagbura ay mag-iiwan sa mga iyon na walang masabing sino ang nagdala.

---

## Mga review

**Peke ang buong write-review screen.** `Future.delayed(800ms)` tapos isusulat
sa lokal na mock. **Walang review na nakarating sa server kahit kailan** — kaya
walang lumalabas sa produkto. Ganoon din ang listahan ng review: mula sa mock.

Totoo na ang dalawa. Ang review ay may **bituin, komento, at hanggang 4 na
larawan**, at nakikita sa produkto ng seller.

**Nakasulat ito laban sa order, hindi sa produkto.** Iyon ang buong garantiya
ng "legit": tinatanggap lang ng server ang review mula sa buyer na siyang
umorder, kapag **completed** na ito, at **isang beses lang**. Hindi
makakapag-post ang kakumpitensya, at hindi rin ang hindi naman bumili.

Kaya wala nang "Write a review" sa listahan ng review — walang alam na order
ang screen na iyon. Nagsisimula ito sa mismong order.

**Ang larawan ang bumubuhay sa review.** Ang "maganda po" ng estranghero ay
maliit ang halaga; ang litrato ng aktwal na sakong dumating ay kaya nang
timbangin ng susunod na bumibili.

**Blangkong kahon sa ilalim ng bawat review.** Object pala ang `sellerReply`
(`{ text, repliedAt }`), pero teksto ang binabasa ng app. Ang
`{text: , repliedAt: null}` ay **hindi** empty string, kaya "may sagot" ang
tingin ng bawat review at gumuguhit ng blangkong kahon sa ilalim nito.

**Isang tunay na bug na nahuli ng test:** hindi nagka-cast ang mongoose sa
`$match` ng aggregate gaya ng ginagawa nito sa `find()`. String ang dumarating
na `productId` mula sa URL, at **hindi kailanman tumutugma ang string sa
naka-imbak na ObjectId sa loob ng aggregate** — tahimik, walang error. Kaya
**zero bituin mula sa zero review** ang isinasagot ng bawat produkto kahit may
nakaupo nang review doon.

---

## Paghahatid at mapa

**May mapa na sa dalawang panig.** Parehong OpenStreetMap tiles — `flutter_map`
sa mobile, `react-leaflet` sa web — kaya iisang mapa ang tinitingnan ng buyer at
ng seller, at walang API key na kailangan.

Tatlong punto ang ipinapakita: ang **tindahang pinagkunan**, ang **pinto na
patutunguhan**, at ang **rider** kapag may ibinabahaging posisyon. Hindi ito
naghihintay sa rider — alam na ang dalawang dulo sa oras na may order, at iyon
na ang kalakhan ng nagpapadama na may pananagutan ang paghahatid.

| Punto | Saan nanggagaling | Sino ang nagtatakda |
|---|---|---|
| Pickup | `User.pickupLat/Lng` | Seller, sa "Pin my shop" |
| Dropoff | `addresses[].lat/lng` | Buyer, sa "Pin here" |
| Rider | `Order.delivery` | Seller, sa "Share my location" |

**Itinatapon dati ng `LocationService` ang koordinado.** Ibinabalik lang nito
ang teksto ng address — ang tumpak na kalahati ng location na kapapayag pa lang
ng buyer ay basta na lang nawawala.

**Naka-snapshot sa `Order.route` ang dalawang dulo sa checkout.** Ang buyer na
nag-edit o nagbura ng address pagkatapos umorder ay hindi dapat makapagpalit ng
destinasyon ng order na nasa daan na. Ang `addressId` ang ipinapadala ng
checkout, hindi ang koordinado — binabasa ng server ang pin mula mismo sa
naka-save na address, kaya walang kliyenteng makakapagpahatid sa lugar na hindi
naman pinili ng buyer.

**Kada order row ang mapa, hindi kada order.** Ang basket na hati sa dalawang
seller ay dalawang biyahe mula sa dalawang tindahan.

**₱0 ang bawat item.** `lineTotal` ang ipinapadala ng buyer order rows, pero
`subtotal` ang binabasa ng app — walang nahanap, kaya zero. Tama naman ang
subtotal sa ibaba, kaya mukhang libre ang produkto sa isang linya at bayad sa
kabila.

**Sa address ito napupunta, hindi sa kung nasaan ka ngayon.** Ito ang
pinakamahalagang pagbabago. Kinukuha na ng server ang punto mula sa **barangay,
lungsod, at probinsya** na pinili sa dropdown — awtomatiko, walang pipindutin.
Ang bumibili mula sa eskwelahan ay hindi na mapapadalhan sa eskwelahan.

**Ang street line ay hindi kailanman ipinapadala sa geocoder.** Tanging ang
tatlong structured na field. Ang "Blk 48 Lot 71 (white house po bahay namjn)"
ay magre-resolve sa lugar na tiyak at mali, at ang rider na magtitiwala roon ay
mas malalayo pa sa pinto kaysa kung binasa na lang niya ang mga salita.

Barangay ang tamang antas. Inilalagay nito ang pin sa tamang bahagi ng tamang
bayan — iyon naman talaga ang paraan ng paghahatid dito: mapa hanggang
barangay, landmark ang natitira. **Nakasulat na "approximate" ito saanman ito
ipinapakita**, para walang magkamali na ang gitna ng barangay ay isang pinto.

| Antas | Kahulugan | Sino |
|---|---|---|
| `exact` | Nakatayo sa mismong pinto | Buyer, sa "Mark the exact spot" |
| `approximate` | Ang barangay ng address | Server, awtomatiko |
| wala | Hindi mahanap sa mapa | Sinasabi nang diretso |

**Nominatim ng OpenStreetMap** ang gamit — parehong data ng tiles, walang API
key. Naka-cache ang bawat sagot sa `GeoCache` (hindi gumagalaw ang barangay),
isang request lang sa bawat segundo, at may tunay na User-Agent — mga kondisyon
ito ng paggamit, hindi mungkahi.

May migration para sa mga luma: `node src/scripts/backfillAddressPins.js`.
Napatakbo na — **19 order ang nabigyan ng destinasyon**, kasama ang AGF-978429.

---

## Splash — tatlong screen tuwing bubuksan

Tatlong screen sa pagbukas ng app, sinasagot ang tatlong tanong ng bagong
bumibili: kanino galing, magkano ang isang sako, at paano ko masusundan.

| # | Larawan | Sinasabi |
|---|---|---|
| 1 | `ricefarm.png` | Sinuri ang permit ng bawat tindahan — hindi palamuti ang badge |
| 2 | `ricefarm2.jpg` | 1 hanggang 50 kg, may presyo bawat sako, hindi mapipindot ang ubos |
| 3 | `ricefarm3.png` | Sundan sa mapa, at may litrato pagdating |

**Wala rito ang hindi naman totoo** — tatlong bagay na tunay ngang nagagawa ng
system. Ang pambungad na sobra sa pangako ay pagkadismaya na may countdown.

Kusa itong umuusad tuwing 2.6 segundo, kaya nakikita — hindi hinihintay. Pero
ang unang swipe ay nagpapatigil sa timer nang tuluyan: ang umabot sa screen ay
gustong magbasa sa sarili niyang bilis, hindi makipagkarera. Laging may Skip.

**Nire-restore ang session sa likod nito.** Ang splash na tumatakip sa
trabahong nangyayari na ay walang halaga; ang bumibilang lang hanggang tatlo ay
bayad.

Parallax ang larawan, umaahon ang teksto isang beat pagkatapos, at humahaba ang
tuldok ng kasalukuyang pahina. Buong screen ang nagsi-swipe, pati ang larawan.

### Dalawang mali sa unang gawa

**Hindi ito nakikita.** Naka-gate ito sa "hindi pa naka-sign in" at "isang beses
lang" — kaya ang telepanong naka-sign in ay hindi man lang ito naaabot, at ang
pag-sign out ay diretso sa Welcome, nilalaktawan pa rin. Splash ang hiningi,
onboarding ang ginawa ko.

**Umaapaw ang pindutan.** Nakapirmi sa 150pt ang lapad, pero ang "Get started"
kasama ang icon ay hindi kasya. Sinusukat na nito ngayon ang sarili — ang
matigas na numero ay aapaw sa oras na magbago ang salita o lumaki ang font ng
telepono.

Nahuli ang pangalawa ng `test/splash_test.dart` (6 na test): tatlong screen,
kusang pag-usad, pagtigil ng timer sa swipe, Skip, at ang pagbabago ng pangalan
ng pindutan. Walang nakabantay noong una — kaya hindi nahuli.

---

## Mobile — hitsura at galaw

- Apat na tab: Home · Shop · Messages · Profile. Ang orders ay nasa loob ng
  Profile (All, To Pay, To Ship, To Receive, To Review, Return — kasama ang
  cancelled).
- Claymorphism sa buong app, `Plus Jakarta Sans`, mas maliit na curve.
- **Tinanggal lahat ng mock data.** Walang pekeng promo banner (walang
  promotions system), walang Follow (walang follow system).
- Profile ng seller sa loob ng product detail, sa pagitan ng presyo at reviews —
  doon nagpapasya ang buyer kung mapagkakatiwalaan ang nagbebenta.
- Tatlong banner ng agrikultura na may larawan at maikling impormasyon.
- Recommendations sa ilalim ng product detail, hindi sa Home.
- Search bar sa Shop lang.

---

## Nakabitin pa

- **Walang live na mensahe.** Tumatakbo ang Socket.io sa server pero walang
  kliyenteng kumokonekta. Kailangang muling basahin ng app. Ito ang susunod na
  malinaw na hakbang.
- **Mock pa rin ang notifications sa mobile.**
- **Peke ang `ForgotPasswordPage.jsx` sa web** — `setTimeout` lang.
- **Bukas sa kahit sino ang `/api/products/stock/low` at `/stock/out`.**
- **Hindi pa nasusubukan nang buo ang GCash** hangga't walang seller na
  `payout.status === 'verified'`.
- **Walang routing sa mapa** — tuwid na linya, hindi daan.
- **Manu-manong ibinabahagi ng seller ang posisyon** — walang background
  tracking.

---

## Mga test

```bash
# Hindi kailangan ng server
flutter test

# Kailangan ng tumatakbong backend at naka-seed na account
flutter test --tags fixture --run-skipped -j 1
```

Kailangan ng `--run-skipped`. Kung wala ito, mananaig ang `skip` sa
`dart_test.yaml` at **walang tatakbo kahit isa**.

| Suite | Bilang | Kailangan |
|---|---|---|
| `flutter test` (untagged) | 62 | wala |
| `chat_test.dart` | 11 | `chat@agrifair.invalid`, seller na may stock |
| `cart_test.dart` | 10 | `cart@agrifair.invalid` |
| `delivery_test.dart` | 7 | `chat@agrifair.invalid`, seller na may naka-set na `pickupLat/Lng` |
| `payment_test.dart` | 8 | isang seller na aprubado ang payout, isang hindi |
| `review_test.dart` | 6 | isang **completed** na order na hindi pa nare-review |

Walo na ang `delivery_test.dart`: kasama na kung paano naipupwesto sa barangay
ang address na hindi naka-pin, at kung paano **walang iniimbento** kapag wala
sa mapa ang lugar.

Ang natitirang fixture files (`auth_flow`, `checkout`, `password_reset`,
`unverified_login`, `verification_gate`) ay humihingi ng mga account na wala pa
sa database — hindi sila bagsak dahil sa code, kulang lang ang seed.

Dalawang bitag na nadapaan na, pareho tungkol sa **pag-uulit ng fixture tests**:

- Isang test ang nag-aakalang lahat ng mensahe sa isang thread ay sa buyer.
  Totoo iyon hanggang sa may order na nagsulat ng sarili nitong mensahe roon —
  at hanggang sa **sumagot ang seller**, na siya namang dapat mangyari. Ang
  tamang tinatanong: napupunta ba sa tunay na tao ang bawat mensahe? Ang
  `senderUserId` na 0 ang bug, hindi ang pagsagot ng seller.
- Nililinis ng `delivery_test` ang mga address bago magsimula, kung hindi ay
  ang naiwan ng nakaraang takbo ang magdedesipisyon kung naka-pin ba ito.
- **May sariling rate limiter ang login (5 kada 15 minuto).** Ang sunod-sunod
  na pagpapatakbo ng limang fixture suite pagkatapos ng ilang manu-manong
  login ay tatama dito, at `setUpAll` ang babagsak. Hindi ito regression —
  maghintay lang.
