# Ads Safety Checklist (AdMob)

Use this checklist when you put real ads in. Rival arrow games got 1-star reviews for
scam ads ("your phone has a virus / bank at risk"), 30-second ads they could not skip,
and too many ads.

## 1. Block scam and adult ads (AdMob dashboard → app → Blocking controls)

- **Content rating:** set *Maximum ad content rating* to **G** (or **PG**).
- **Sensitive categories:** block Gambling, Dating, Get-rich-quick, Drugs & supplements,
  Sexual & suggestive, References to sex, Weight loss, and anything else you don't want.
- **Ad review center:** open it every week. Block any ad that looks like a fake warning,
  virus alert, "system protection" or a bank-security message.
- **Mediation:** only use well-known networks. Every extra network brings more risk of
  scam ads.
- **Advertiser URLs:** if players report a bad ad, block its website here.

## 2. Ad length and frequency (ad unit settings)

- **Interstitial ad unit:** turn on *Frequency capping*, for example 1 ad every 3 minutes.
- **Optional:** in the interstitial unit, allow only *Display* (image) ads, not *Video*.
  You earn less, but there are no long unskippable videos.
- The game already follows these rules (see `scripts/AdManager.gd`):
  - no ad when the app opens or returns from the background
  - FIRST RELEASE: interstitials are switched OFF (AdManager.INTERSTITIALS_ENABLED = false);
    only player-chosen rewarded videos run. Turn them on in an update after ~1000 downloads.
  - when on: an interstitial only every 5 won levels, from level 15 on, never after a loss,
    at least 4 minutes after any other ad, and at most 5 a day. These limits are by time
    and per day, so they stay the same however many levels the game gets.
  - a rewarded video only when the player taps a button, and one video = the full reward
  - an ad that hangs is closed after 75 s and the player still gets the reward
- **Do not turn on** AdMob's "high engagement" settings (longer skip times for
  interstitial and rewarded ads).

## 3. Invalid traffic ("Ad serving is limited")

AdMob limits ads when clicks or views look fake. It is about *odd traffic*, not about
showing many ads. To stay safe:

- **Never click your own real ads**, and never ask friends or family to click.
- **Test with test ads only.** Add your own phones to `TEST_DEVICE_IDS` in
  `scripts/AdManager.gd` before installing a real-ads build (the ID is printed in
  `adb logcat` the first time the app loads an ad).
- **Never buy installs or traffic** from unknown sites.
- **app-ads.txt:** the file is at `E:\Anant Originals\public\app-ads.txt`
  (www.anantoriginals.com/app-ads.txt). Put the real `pub-` ID in it once the AdMob
  account exists, and set the Play Store listing's website to https://www.anantoriginals.com.
- New apps often get a limit for the first weeks while Google checks the traffic. It lifts
  on its own if the traffic is clean.
- The game also protects itself (`scripts/AdManager.gd`):
  - at most 5 interstitials and 25 rewarded videos per player per day
  - the shop's free-coin video (+100 coins) at most 5 times per day (GameData.COIN_VIDEOS_PER_DAY)
  - input is held 0.6 s before an ad opens, so a tap on "Next" can't become an ad click
  - ads are limited to content rating G in the code as well

- **Closed testing (12 testers, 14 days):** that build must use test ads too.
- **No text that asks players to watch or click ads to "support us".**
- **No mediation at the start.** AdMob only.

## 4. Play Console and accounts

- Fill in honestly: *Contains ads*, *Data safety* (AdMob collects device IDs, IP,
  interactions, diagnostics), *Advertising ID* declaration, IARC content rating.
- **Target audience: 18+ only** (Play Console → App content → Target audience and content).
  Never promote the game to children (for example on the kids YouTube channel), and keep
  the store icon, screenshots and text grown-up; if Google decides it appeals to children,
  the Families policy applies anyway.
- Players in the EEA/UK can reopen Google's consent form from
  *Options → Privacy Preferences → Ad consent choices* (shown only where needed).
- Finish the AdMob payments setup: PIN, identity check, tax info.
- Check the AdMob *Policy center* every week and fix issues in time.
- Update the target Android API level every year when Play asks.

## 5. Saved level

If the app is closed, killed or crashes in the middle of a level, the level continues
where the player left it. The file is stored **only on the player's own phone**
(`user://resume_level.save`) and is never sent anywhere.

---

### हिंदी में छोटा सार

- AdMob → Blocking controls: content rating **G**, गलत कैटेगरी (जुआ, डेटिंग, नकली दवा
  वगैरह) ब्लॉक करें, और हर हफ़्ते *Ad review center* में नकली "वायरस/बैंक" वाले ऐड ब्लॉक करें।
- Interstitial ad unit में frequency cap लगाएँ। चाहें तो सिर्फ़ image ads रखें, लंबे वीडियो नहीं।
- गेम में पहले से ये नियम हैं: गेम खोलने पर कोई ऐड नहीं, पहले 14 लेवल ad-free, फिर 5 लेवल में
  एक ऐड, दो ऐड के बीच कम से कम 4 मिनट, हारने पर ऐड नहीं, और अटका हुआ ऐड 75 सेकंड में अपने-आप
  बंद होकर इनाम दे देता है। ये नियम समय पर चलते हैं, इसलिए कितने भी लेवल हों, ऐड उतने ही रहेंगे।
- अपने असली ads पर कभी click न करें, न किसी से करवाएँ। अपने phone को `TEST_DEVICE_IDS` में डालें।
- गेम में रोज़ की सीमा है: 5 interstitial और 25 rewarded video। सिक्कों वाला वीडियो (+100) दिन में सिर्फ़ 5 बार। ऐड खुलने से पहले 0.6 सेकंड tap बंद रहता है।
- AdMob की "high engagement" setting चालू न करें। Target audience सिर्फ़ 18+ रखें, और गेम को बच्चों के
  channel पर promote न करें।
- `app-ads.txt` वेबसाइट पर तैयार है। असली AdMob ID मिलने पर उसमें एक लाइन जोड़नी है।
- बीच में छूटा हुआ लेवल सिर्फ़ यूज़र के फ़ोन में सेव होता है, कहीं भेजा नहीं जाता।
