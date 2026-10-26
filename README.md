# ClashXMarv / Hero Arena

An original superhero-themed lane-battler prototype for iOS, built with Expo and React Native. This repository is the starting point for the project; it is not affiliated with or endorsed by Marvel or Supercell.

## Status
Prototype stage. The initial playable foundation, opponent AI, balance testing, artwork/animation, and a verified iPhone IPA are separate milestones. No IPA is committed to this repository.

## Local development

```bash
npm install
npm test
npx expo start
```

## iOS build

The GitHub Actions workflow uses Expo Application Services (EAS). Add an `EXPO_TOKEN` repository Actions secret and configure the EAS project before running the workflow. A successful cloud build is required before an IPA can be claimed as available.
