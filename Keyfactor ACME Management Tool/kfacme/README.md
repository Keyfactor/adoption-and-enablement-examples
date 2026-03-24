# kfacme

**kfacme.exe** is a Windows command-line application for managing ACME-related administration tasks through interactive menus.

## How to use

### Run the executable

Open a terminal in the folder where `kfacme.exe` is located, then run:
```PowerShell
.\kfacme.exe
```
If you prefer Command Prompt:
```cmd
kfacme.exe
```

---

## What the app does

This tool presents a menu-based interface for common ACME administration tasks, including:

- viewing the claim subject
- managing EAB keys
- managing registered accounts
- managing claims
- managing identifiers
- managing system settings

You choose actions by entering the number shown in the menu.

---

## Main menus

Depending on how the app starts up and what access you have, you may see one of the following menus.

## Administration Menu

This is the full admin menu.

### Options

| Option | Action |
|---|---|
| `1` | Get claim Subject |
| `2` | Get EAB Keys |
| `3` | Delete EAB Keys |
| `4` | Manage Registered Accounts |
| `5` | Manage Claims |
| `6` | Manage Identifiers |
| `7` | Manage System Settings |
| `8` | Exit Application |

### What each option does

#### 1. Get claim Subject
Displays the subject associated with the current claim context.

#### 2. Get EAB Keys
Retrieves External Account Binding keys.

#### 3. Delete EAB Keys
Deletes existing EAB keys.

#### 4. Manage Registered Accounts
Opens the submenu for account management.

#### 5. Manage Claims
Opens the submenu for claim-related tasks.

#### 6. Manage Identifiers
Opens the submenu for identifier-related tasks.

#### 7. Manage System Settings
Opens the submenu for system configuration tasks.

#### 8. Exit Application
Closes the application.

---

## Account Admin Menu

This is a smaller admin menu focused on account-related work.

### Options

| Option | Action |
|---|---|
| `1` | Get claim Subject |
| `2` | Get EAB Keys |
| `3` | Delete EAB Keys |
| `4` | Manage Registered Accounts |
| `5` | Exit Application |

### What each option does

#### 1. Get claim Subject
Displays the claim subject for the account admin workflow.

#### 2. Get EAB Keys
Retrieves EAB keys for the current account context.

#### 3. Delete EAB Keys
Removes EAB keys.

#### 4. Manage Registered Accounts
Opens the registered accounts submenu.

#### 5. Exit Application
Closes `kfacme.exe`.

---

## Submenus

Some menu options open additional screens:

- **Accounts** — manage registered accounts
- **Claims** — view and manage claims
- **Identifiers** — manage identifiers
- **System Settings** — adjust application or ACME-related settings

These submenus follow the same pattern:
1. choose an option
2. enter any required value
3. review the result or go back

---

## Navigation basics

- Type the number of the menu option you want.
- Press `Enter`.
- If you enter an invalid option, the app will show an error and re-display the menu.
- Use the exit option to close the program cleanly.

---

## Example usage
```
powershell PS C:\Tools\kfacme> .\kfacme.exe 
=== Administration Menu === 
[1] Get claim Subject 
[2] Get EAB Keys 
[3] Delete EAB Keys 
[4] Manage Registered Accounts 
[5] Manage Claims 
[6] Manage Identifiers 
[7] Manage System Settings 
[8] Exit Application 
Choose what action you want to execute (1-8):
```

---

## Notes

- This is a terminal app, so all interaction happens in the console.
- The menu structure is designed to keep tasks organized and easy to find.
- If you add new menu items later, update this README so users can quickly understand what changed.

---
