singleClickSignal = Action.signal
.next ->
  display01.innerText += " + "

doubleClickPump = Action.signal
.next do ->
  last = new Data()
  ->
    now = new Data()
    if now - last > 300
      last = now
    else
      display02.innerText += " + "

singleClickPump = singleClickSignal.go()
DoubleClickPump = DoubleClickSignal.go()

btn.onclick = (e) ->
  singleClickPump e
  doubleClickPump e
