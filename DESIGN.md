# Design of the Application

```txt
+----------------------------------------------------------------------------+
|  File   Edit   View   Object                                       Help    |  `menu bar`
+----------------------------------------------------------------------------+
|  [bang] [tgl] [num] [msg]                        [edit] [grid] [fit]       |  `toolbar`
+--------------+----------------------------------------------+--------------+
|              |  `canvas`                                    | `inspector`  |
|  search[__]  |                                              |              |
|  `selector`  |                                              |              |
+--------------+----------------------------------------------+--------------+
|  [*] Vibe code                                                     [v]     |  `drawer header`
|  `drawer body`                                                             |
|  [ describe a graph to build...                                  ] [ ^ ]   |  `drawer input`
+----------------------------------------------------------------------------+
|  STATUS   help: "osc~ - cosine oscillator"          zoom 100%    x,y       |  `status`
+----------------------------------------------------------------------------+
```

Coordinate spaces: everything is **pixel space** (`ortho(0,0,w,h)`, top-left
origin) except `canvas`, which is **world space** (`Camera2D`, scissor-clipped).

---

## `menu bar`

* Persistent dropdown row across the top.
* Dimensions X: `[origin : end]`
* Dimensions Y: `[origin : menu_bar_h]`

| Property        | Spec                                                         |
|-----------------|--------------------------------------------------------------|
| File            | New, Open, Save, Save As, Recent, Quit                       |
| Edit            | Undo, Redo, Cut, Copy, Paste, Delete, Select All             |
| View            | Zoom In, Zoom Out, Fit, Reset Camera, Toggle Grid            |

---

## `toolbar`

* Object palette and view controls. Edit-mode chrome.
* Dimensions X: `[origin : end]`
* Dimensions Y: `[origin : menu_bar_h + toolbar_h]`

---

## `selector`

* Searchable object browser down the left edge.
* Dimensions X: `[origin : origin + selector_w]`
* Dimensions Y: `[origin + menu_bar_h + toolbar_h : origin + end - drawer_h - status_h]`

---

## `canvas`

* The patch graph itself. The only world-space region - a "hole" in the pixel UI.
* Dimensions X: `[origin + selector_w : origin - inspector_w]`
* Dimensions Y: `[origin + menu_bar_h + toolbar_h : origin + end - drawer_h - status_h]`

---

## `inspector`

* Properties of the currently selected object, down the right edge.
* Dimensions X: `[origin + end - inspector_w : origin + end]`
* Dimensions Y: `[origin + menu_bar_h + toolbar_h : origin + end - drawer_h - status_h]`

---

## `drawer header`

* Top bar of the vibe-code chat. Always visible while the drawer exists; it's the collapse handle.
* Dimensions X: `[origin : end]`
* Dimensions Y: `[origin + end - drawer_h - status_h : origin + end - drawer_h - status_h + drawer_header_h]`

---

## `drawer body`

* Scrollback of the chat conversation.
* Dimensions X: `[origin : end]`
* Dimensions Y: `[origin + end - drawer_h - status_h + drawer_header_h : origin + end - status_h - drawer_input_h]`

---

## `drawer input`

* Prompt entry row at the bottom of the drawer.
* Dimensions X: `[origin : end]`
* Dimensions Y: `[origin + end - status_h - drawer_input_h : origin + end - status_h]`

---

## `status`

* Thin info strip along the bottom.
* Dimensions X: `[origin : end]`
* Dimensions Y: `[origin + end - status_h : origin + end]`


