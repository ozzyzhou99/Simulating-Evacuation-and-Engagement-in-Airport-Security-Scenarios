extensions [gis]

globals [airports-raster
  cost-raster
  safe-exits
  evacuated-passengers  ; Record the number of passengers evacuated to the exit
  killed-person    ; Record number of passengers killed by gunman
  shots-fired          ; boolean to track if any shots have been fired
  time-step-count      ; record the time
]

breed [shooters shooter]
breed [passengers passenger]
breed [guards guard]

passengers-own [health
  evacuating?  ; Whether the passenger is evacuating
]
guards-own [health]
shooters-own [health]

patches-own [
  area-type  ; Store values from raster file
  exit  ; 1 if it is an exit, 0 if it is not
  elevation  ; Cost distance for storage to exit
  path-count  ; number of passes
]

to setup
  clear-all
  set time-step-count 3
  set evacuated-passengers 0
  set killed-person 0
  set shots-fired false  ; Initialize to false
  load-airport-data
  setup-patches
  setup-agents
  reset-ticks
end

to load-airport-data
  ; Load airport ASCII raster data
  set airports-raster gis:load-dataset "data/rastert_feature1.asc"
  set cost-raster gis:load-dataset "data/rastert_costdis2.asc"  ; Load cost raster data
  gis:set-world-envelope gis:envelope-of airports-raster
end

to setup-patches
  ask patches [
    let value gis:raster-sample airports-raster self
    let cost gis:raster-sample cost-raster self  ; Get cost values from cost data raster
    set elevation cost  ; Set the elevation of each patch to the cost value
    ifelse value = nobody [
      set area-type 0  ; Outside the airport
      set pcolor grey  ; Visual cue for outside airport
    ]
    [
      set area-type value
      ; Color coding based on area-type
      set pcolor ifelse-value (member? value [1 2 3 6 7 8]) [white] [
        ifelse-value (member? value [4 5]) [green] [grey]
      ]
      if member? value [6 7 8] [
        set pcolor yellow
        set exit 1
      ]
      set safe-exits (value = 6 or value = 7 or value = 8)
      if safe-exits [set pcolor yellow set exit 1]
    ]
  ]
end


to setup-agents
  clear-turtles

  ; Generate passengers
  let passenger-patches patches with [area-type = 1 or area-type = 2 or area-type = 3] with [all? neighbors [area-type = 1 or area-type = 2 or area-type = 3]]
  ask n-of min(list number-of-passengers count passenger-patches) passenger-patches [
    sprout-passengers 1 [
      set color blue
      set shape "person"
      set size 10
      set health 2  ; Passenger health
      set evacuating? false  ; Initialize evacuation status to false
    ]
  ]

; Call the dedicated procedure for setting up the gunner
   ; Find all patches of type 2
  let candidate-shooter-patches patches with [area-type = 2]
  let candidate-shooter-patches3 patches with [area-type = 3]

  ; Filter out patches completely surrounded by areas of the same type
  let shooter-patches candidate-shooter-patches with [
    all? neighbors [area-type = 2]
  ]

   let shooter-patches3 candidate-shooter-patches3 with [
    all? neighbors [area-type = 3]
  ]

  ; Spawn gunmen, making sure not to exceed the specified number and only spawn on eligible patches
  ask n-of min(list (2 * number-of-shooters / 3) count shooter-patches) shooter-patches [
    sprout-shooters 1 [
      set color black
      set shape "person"
      set size 10
      set health 5  ; Set the gunner's health
    ]
  ]

   ask n-of min(list (number-of-shooters / 3) count shooter-patches3) shooter-patches3 [
    sprout-shooters 1 [
      set color black
      set shape "person"
      set size 10
      set health 5  ; Set the gunner's health
    ]
  ]

  ; Generate security personnel
  let guard-patches-1 patches with [area-type = 1] with [all? neighbors [area-type = 1]]
  let guard-patches-2 patches with [area-type = 2] with [all? neighbors [area-type = 2]]
  let guard-patches-3 patches with [area-type = 3] with [all? neighbors [area-type = 3]]

  ask n-of min(list (number-of-guards / 5) count guard-patches-1) guard-patches-1 [
    sprout-guards 1 [
      set color green
      set shape "person"
      set size 10
      set health 5  ; Security health value
    ]
  ]
  ask n-of min(list (4 * number-of-guards / 5) count guard-patches-2) guard-patches-2 [
    sprout-guards 1 [
      set color green
      set shape "person"
      set size 10
      set health 5
    ]
  ]
    ask n-of min(list (1 * number-of-guards / 5) count guard-patches-2) guard-patches-3 [
    sprout-guards 1 [
      set color green
      set shape "person"
      set size 10
      set health 5
    ]
  ]
end


to go
  ; Propagate evacuation status
  ask passengers [
    if not evacuating? [  ; Ensure evacuating? is correctly evaluated as a boolean
      if any? other passengers in-radius 50 with [evacuating?] [
        set evacuating? true
      ]
    ]
  ]

  ; Move only evacuating passengers
  ask passengers with [evacuating?] [
    move-towards-exit
  ]

  ; Move only evacuating passengers
  ask passengers with [evacuating?] [
    move-towards-exit
  ]

  ask shooters [
    update-shooter
  ]

  ask guards [
    approach-closest-shooter
    shoot-at-shooter
  ]

  ; Check if simulation should end
  if shots-fired and not any? passengers with [evacuating?] [
    print "All passengers have been evacuated or killed, simulation ends."
    stop  ; Stop the simulation
  ]

  tick
  set time-step-count time-step-count + 3
end

to move-towards-exit
  if evacuating? [
    ifelse approach-shooter? and random-float 1 < 0.1 [
      let nearest-shooter min-one-of shooters [distance myself]
      if nearest-shooter != nobody and distance nearest-shooter < 5 [
        face nearest-shooter
        fd 1
        ; If the distance is less than 5, attack the shooter
        ask nearest-shooter [
          set health health - 1
          if health <= 0 [ die ]  ; If the gunman's health is 0, the gunman dies.
        ]
      ]
    ][
      let target min-one-of neighbors [elevation]  ; Choose the patch with the lowest cost
      if target != nobody [
        face target
        move-to target
        ask target [
          set path-count path-count + 1
          update-color  ; update color
        ]
        if any? (patches with [exit = 1] in-radius 2) [
          set evacuated-passengers evacuated-passengers + 1
          die  ; Passengers are considered evacuated if they are within 5 patch units of any exit
        ]
      ]
    ]
  ]
end



to update-color
  ; Update the color based on the number of passes
  set pcolor scale-color blue path-count 0 10
end

to update-shooter
  ; Check if there is a target within the shooting range
  let target min-one-of (turtles with [breed = passengers or breed = guards]) [distance myself]
  ifelse target != nobody and distance target < shooting-range [
    shoot-at-target target
  ]  [
    move-shooter  ;If there is no target or the target is not in range, move at cost
  ]
end

to shoot-at-target [target]
  ask target [
    set health health - 1
    if health <= 0 [
      set killed-person killed-person + 1
      die  ; If the target's health is 0, the target dies.
    ]
  ]
  set shots-fired true  ; Update when a shot is fired
    ; Trigger evacuation of nearby passengers
  ask passengers with [distance myself < 150] [
    set evacuating? true
  ]
end


to move-shooter
  ; Find the nearest passenger
  let nearest-passenger min-one-of passengers [distance myself]

  if nearest-passenger != nobody [
    face nearest-passenger  ; For the nearest passenger
    let best-patch min-one-of neighbors with [elevation >= 0] [distance nearest-passenger]
    ; Check if there are any eligible patches
    if best-patch != nobody [
      face best-patch
      move-to best-patch  ; Move to selected patch
    ]
  ]
end

to approach-closest-shooter
  ; Check if there is a shooter present
  if any? shooters [
    ; If there is a shooter, find the nearest shooter
    let target min-one-of shooters [distance myself]
    if target != nobody [  ; Check again whether the target exists
      ; Check the surrounding neighbors for patches with elevation > 0 and choose to move towards the target
      let target-patch min-one-of neighbors with [elevation > 0] [distance target]
      if target-patch != nobody [
        face target-patch
        move-to target-patch
      ]
    ]
  ]
end




to shoot-at-shooter
  ; Check if there is a shooter present
  if any? shooters [
    ; If there is a shooter, find the nearest shooter
    let target min-one-of shooters [distance myself]
    ; Check if the target exists and is within range
    if target != nobody and distance target < shooting-range [
      ask target [
        set health health - 1
        if health <= 0 [ die ]
      ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
237
10
846
540
-1
-1
1.0
1
10
1
1
1
0
0
0
1
0
600
0
520
1
1
1
ticks
30.0

BUTTON
21
31
101
71
Setup
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
21
92
193
125
shooting-range
shooting-range
0
20
10.0
1
1
m
HORIZONTAL

SLIDER
20
148
208
181
number-of-passengers
number-of-passengers
0
500
50.0
5
1
NIL
HORIZONTAL

SLIDER
21
203
193
236
number-of-guards
number-of-guards
0
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
21
260
195
293
number-of-shooters
number-of-shooters
0
5
4.0
1
1
NIL
HORIZONTAL

BUTTON
121
31
196
72
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
902
35
1218
248
Number of passengers evacuated
Simulation time
Number of passengers evacuated
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Evacuated" 1.0 0 -13345367 true "" "plotxy time-step-count count passengers"

MONITOR
22
316
173
361
evacuated-passengers
evacuated-passengers
17
1
11

MONITOR
22
386
153
431
killed-person
killed-person
17
1
11

PLOT
910
282
1219
497
Number of shooter
Simulation time
number of shooter
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy time-step-count count shooters"

SWITCH
22
455
197
488
approach-shooter?
approach-shooter?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

This is an airport evacuation model

## HOW IT WORKS

Three types of agents, passengers, guards, and shooters, interact with each other

## HOW TO USE IT

Adjust the number of agents of each type, adjust the shooting distance, and switch active defense on and off

## THINGS TO NOTICE

For PCs with poor performance, please do not set too large a number of passengers. This can cause lag.

## EXTENDING THE MODEL

Maybe add some other rules?

## NETLOGO FEATURES

GIS EXTENSION
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
