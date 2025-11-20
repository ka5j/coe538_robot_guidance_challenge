# COE538 Robot Guidance Challenge

## Overview
This repository contains the assembly-based embedded systems project developed for COE538 – Microprocessor Systems at Toronto Metropolitan University.  
The project focuses on designing and implementing a modular robot guidance system for the eebot platform using the HCS12/9S12 microcontroller.  
The robot reads guider sensors, performs line tracking, detects junctions, learns a valid maze path, and returns to the start using the learned route.

This repository is organized to be clean, readable, and educational, making it suitable for academic demonstration and reference.

## Features
- Guider sensor subsystem (5 optical sensors: A, B, C, D, E–F differential)
- LCD display system for debugging and status output
- ADC management for sensor sampling on channel AN1
- Motor control subsystem with direction and speed control
- Timer overflow–based timing system for generating delays and timed behaviours
- Modular state machine architecture
- Reverse traversal after maze completion
- Fully commented and structured assembly code

## Project Goals
1. Read guider sensors reliably using the HCS12 ADC.
2. Follow a black electrical tape line using differential steering.
3. Detect left turns, right turns, T-junctions, and dead ends.
4. Build a table of taken turns during exploration.
5. Use the learned turn list to return to the start with no mistakes.
6. Present the entire solution through a clean, modular codebase.

## Repository Structure
```
coe538_robot_guidance_challenge/
│
├── main.asm             # Entry point of the robot firmware
├── read_guider.inc      # Sensor, LCD, ADC, and guider utilities
├── motors.inc           # Motor control and timed motion routines
├── timers.inc          # Timer overflow setup and ISR logic
├── read_guider.asm      # Reference guider demo code (Lab 7)
├── derivative.inc       # MCU hardware definition file
├── LICENSE              # Academic-safe license restrictions
└── README.md            # Project documentation
```

## Hardware Requirements
- HCS12/9S12C32 microcontroller board  
- eebot platform with:
  - 4 absolute CdS sensors (A, B, C, D)
  - 1 differential sensor pair (E–F)
  - 74HC4051/138 sensor multiplexer
  - Dual DC motors with H-bridge driver
  - Mechanical bumpers
  - 20×2 character LCD
- Stable power supply or battery pack

## Software Requirements
- CodeWarrior for HCS12/9S12 or an equivalent assembler
- USB/serial programming interface for flashing the MCU
- Basic understanding of assembly language and COE538 lab materials

## Code Architecture

### 1. Guider Module (`read_guider.inc`)
Provides:
- Sensor LED control  
- Sensor multiplexer selection  
- ADC sampling routines  
- LCD initialization and display functions  
- Shadow buffer method for clean LCD updates  
- Hex/ASCII conversion utilities  

### 2. Motor Module (`motors.inc`)
Implements:
- Forward, reverse, stop actions  
- Turn routines (forward-spin and reverse-spin)  
- Direction and speed control via PORTA/PTT  

### 3. Timer Module (`timers.inc`)
Defines:
- Timer prescaler setup  
- Overflow interrupt enabling  
- Overflow ISR that increments a counter at ~23 Hz  
- Timing foundation for state behaviours  

### 4. Main Program (`main.asm`)
Responsible for:
- System initialization  
- Interfacing with guider, motor, and timer modules  
- Displaying sensor data for calibration  
- Hosting future navigation and learning state machine  

## Building and Running

### 1. Setup
Clone the repository:
```bash
git clone https://github.com/ka5j/coe538_robot_guidance_challenge.git
cd coe538_robot_guidance_challenge
```

### 2. Assemble
Open the project in CodeWarrior and build `main.asm`.

### 3. Flash to Hardware
Load the generated S-record to the HCS12 board using your preferred programmer.

### 4. Run and Debug
The robot will initially display real-time sensor readings on the LCD.  
Verify sensor calibration before enabling navigation logic.

## Future Additions
- Complete maze navigation state machine  
- Turn selection logic at junctions  
- Reverse traversal using recorded turn list  
- Refined steering using threshold tuning  
- Optional PID-like steering improvements  
- Additional LCD debugging screens  

## Academic Integrity Notice
This repository is publicly available for learning and educational reference.  
You may not submit this work, in whole or in part, as your own academic assignment or lab.  
Refer to the LICENSE file for full permitted use.

## Acknowledgements
- COE538 teaching staff and lab instructors  
- Toronto Metropolitan University  
- Peter Hiscocks for the original guider demonstration code  
- HCS12/9S12 development community

## Author
**ka5j**  
GitHub: https://github.com/ka5j
