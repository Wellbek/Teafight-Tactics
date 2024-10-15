# Teafight Tactics

Welcome to Teafight Tactics, a self-educational project inspired by RIOT's Teamfight Tactics. Created purely as a personal challenge during my break between exams and the new semester, this game emulates the structure of TFT but wasn’t developed for any purpose beyond learning. Note that it’s not particularly polished!

## Table of Contents

- [Introduction](#Introduction)
- [Features](#Features)
- [Installation & Usage](#Installation-&-Usage)
- [License](#License)

## Introduction

Like Teamfight Tactics, Teafight Tactics is a turn-based strategy game where players assemble a team of units and battle against each others. Each player must strategically position their units and deploy specific combinations and synergies to outsmart and overpower their opponents.

## Features

- **Playable with Up to 8 Players**: The game utilizes GodotSteam, an open-source module and plugin designed for the Godot Engine, enabling seamless integration with Steamworks SDK/API. This allows for hassle-free multiplayer functionality without the need for port-forwarding. Additionally, GodotSteam facilitates the implementation of features such as Steam lobbies, enabling the creation of joinable lobbies for enhanced multiplayer experiences.
Please note that because the game is not registered on Steam (and I'm not planning to do so), it utilizes the dummy spacewar ID. As a result, lobbies from other games using the same system may also be visible. Please only join lobbies associated with this specific game to avoid any unexpected behavior.
- **PvE Rounds**: The first 4 Rounds and every 6th round after are increasingly difficult player versus environment rounds, where on each kill, players have a chance to receive an item or gold.
- **Item System**:  Dropped items can be equipped to a unit to increase its stats. Like in TFT, item components can be combined to more powerful items that have passive effects. The effects are for the most part completely identical to the ones in TFT with very few exceptions.
- **Upgrade System**: When playing the same unit three times and they are at the same level, they are merged to the next higher level.
- **Economy Management**:As the game progresses, players receive more gold after each battle. This gold is additionally increased if a player has lost/won many rounds in a row. Interest accumulates: the more gold a player currently has, the more they receive.
- **Unit Shop**: Gold can be used to purchase units from the shop. The shop is rerolled each round or by button press. Better units have a higher likelihood of occurring in the shop, the higher the player's level.
- **Round-based Combat**: Using the round-robin-tournament algorithm, each player is assigned a new enemy each battle phase. If the number of players is odd, one player gets a free round.
- **Unit Traits**: There are seven types. If a certain number of units of the same type are played on the board, they receive special effects.
- **Unit Abilities**: Currently there is only two different type of abilites.

## Gameplay Showcase

[![Teafight Tactics Gameplay](https://img.youtube.com/vi/ZOJ0OlERgu0/hqdefault.jpg)](https://youtu.be/ZOJ0OlERgu0)

## Installation & Usage

To view and change the source-code, follow these steps:

1. Clone this repository to your local machine
  ```bash
  git clone https://github.com/Wellbek/Teafight-Tactics.git
  ```
2. Download [GodotSteam](https://godotsteam.com/) to utilize the steam multiplayer functions
3. Open the project with GodotSteam Editor

To play the game download the newest version for your operating system in [releases](https://github.com/Wellbek/Teafight-Tactics/releases).

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT), which means you are free to use, modify, and distribute the code as you see fit. See the [LICENSE](LICENSE) file for more details.
