#!/usr/bin/python
import sys
from PyQt4 import QtGui
from PyQt4.QtGui import * 
from PyQt4.QtCore import * 
import subprocess
import re
import signal

def checkIdle():
	out=subprocess.check_output(["/sbin/hdparm","-C","/dev/sda"])
	if re.search(r"idle",out):
		return 0
	elif re.search(r"standby",out):
		return 1
	else:
		print "unknown out:",out
		return 2

def doSuspend():
	out=subprocess.check_output(["/sbin/hdparm","-y","/dev/sda"])

class SystemTrayIcon(QtGui.QSystemTrayIcon):
	idle=0

	@pyqtSlot()
	def count(self):
		self.idle=checkIdle()
		if self.idle==0:
		   self.setIcon(QtGui.QIcon("./Button-Blank-Red-icon.png"))
		elif self.idle==1:
		   self.setIcon(QtGui.QIcon("./accept-icon.png"))
		else:
		   self.setIcon(QtGui.QIcon("./Help-Blue-Button-icon.png"))
		   print ":2"

	def __init__(self, icon, parent=None):
		QtGui.QSystemTrayIcon.__init__(self, icon, parent)
		menu = QtGui.QMenu(parent)
		exitAct = QtGui.QAction('E&xit', self, shortcut='Ctrl+Q',
	        statusTip='Exit the application', triggered=exit)
		exitAction = menu.addAction(exitAct)
		suspAct = QtGui.QAction('&Suspend', self, shortcut='Ctrl+S',
	        statusTip='Suspend the Disk', triggered=doSuspend)
		menu.addAction(suspAct)

		self.setContextMenu(menu)

def sigint_handler(*args):
	QApplication.quit()

def main():
	signal.signal(signal.SIGINT, sigint_handler)

	app = QtGui.QApplication(sys.argv)
	icon1= QtGui.QIcon("./Help-Blue-Button-icon.png")

	w = QtGui.QWidget()
	trayIcon = SystemTrayIcon(icon1, w)

	trayIcon.show()

	timer=QTimer()

	trayIcon.connect(timer,SIGNAL("timeout()"),trayIcon,SLOT("count()"))
	timer.start(2000)

	sys.exit(app.exec_())

if __name__ == '__main__':
    main()

