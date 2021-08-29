# Metis-Mining
Mining Contracts for Metis

## Develop

### Install packages

```
yarn
```

### Compile

```
yarn compile
```

### Test 

```
yarn test
```

## Mock deploy to Metis Network

Create `.env` in root folder and add mnemonic into it, referring to `.env-example`

```
yarn mock-deploy
```

## Deploy to Metis Network

Add `MetisToken` and `DAC` contract address to `.env`

```
yarn deploy
```
