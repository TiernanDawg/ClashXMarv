# ClashXMarv / Hero Arena

An original superhero-themed lane-battler prototype for iOS, built with Expo and React Native. Hero designs and names in this prototype are original archetypes; this project is not affiliated with or endorsed by Marvel or Supercell.

## Current status

The repository now contains an initial battle-screen prototype with eight hero archetypes, energy costs/regeneration, towers, unit movement/combat, a basic automatic AI deployment loop, a match timer, and a hero database screen. This is **early prototype code**, not a feature-complete or balanced Clash Royale equivalent. Controls, combat targeting, AI strategy, and match-end logic still require hands-on testing and refinement. No IPA has been built or verified yet.

## Local development

Requires Node.js 20 or newer.

```bash
npm install
npm test
npx expo start
```

## Configure cloud iOS builds

1. Install the Expo/EAS CLI and sign in to an Expo account.
2. From the project directory, run `eas init` and follow the prompts to link this app to an EAS project. Commit the resulting `extra.eas.projectId` configuration in `app.json`.
3. In GitHub, open **Settings → Secrets and variables → Actions** and add a repository secret named `EXPO_TOKEN` containing an Expo access token.
4. Open **Actions → Build iOS IPA → Run workflow**. The workflow installs dependencies, runs the tests, exports the iOS bundle, then submits a preview build to EAS.
5. Retrieve the IPA from the completed EAS build page. A workflow run is not proof of a successful build unless its final EAS step succeeds.

The EAS project link and access token must be configured by the repository owner; neither is embedded in source code.
