/**
 * Copyright (c) 2013, Fernando Bevilacqua
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 * 
 *   Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 * 
 *   Redistributions in binary form must reproduce the above copyright notice, this
 *   list of conditions and the following disclaimer in the documentation and/or
 *   other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package  
{
	import com.reyco1.multiuser.data.UserObject;
	import com.reyco1.multiuser.debug.Logger;
	import com.reyco1.multiuser.MultiUserSession;
	import flash.events.MouseEvent;
	import org.flixel.*;
	
	public class Multiplayer 
	{
		private const SERVER		:String   = "rtmfp://p2p.rtmfp.net/";
		private const DEVKEY		:String   = "1ec3856c9012a87b8bbf6b99-9669f9adecdc"; // TODO: add your Cirrus key here. You can get a key from here : http://labs.adobe.com/technologies/cirrus/
		private const SERV_KEY		:String = SERVER + DEVKEY;
		
		private const OP_ROTATION 	:String = "R";
		private const OP_SHOT 		:String = "S";
		private const OP_DIE 		:String = "D";
		private const OP_POSITION 	:String = "P";
		
		private var mConnection		:MultiUserSession;
		private var mShips			:Object = {};
		private var mMyName			:String;
		private var mMyColor		:uint;
		
		public function Multiplayer() {
			Logger.LEVEL = Logger.ALL;
			initialize();
		}
		
		public function update() :void {
			var aPlayer :Ship = (FlxG.state as PlayState).player;
			
			// TODO: lower the sending interval so Flash won't die :)
			if (aPlayer != null) {
				sendPosition((FlxG.state as PlayState).player);
			}
		}
		
		private function isPlayerControlled(theShip :Ship) :Boolean {
			return theShip == null || theShip.owner == (FlxG.state as PlayState).player.owner;
		}
		
		protected function initialize():void {
			mConnection = new MultiUserSession(SERV_KEY, "multiuser/test"); 		// create a new instance of MultiUserSession
			
			mConnection.onConnect 		= handleConnect;						// set the method to be executed when connected
			mConnection.onUserAdded 	= handleUserAdded;						// set the method to be executed once a user has connected
			mConnection.onUserRemoved 	= handleUserRemoved;					// set the method to be executed once a user has disconnected
			mConnection.onObjectRecieve = handleGetObject;						// set the method to be executed when we recieve data from a user
			
			mMyName  = "User_" + Math.round(Math.random()*100);
			mMyColor = 0x888888 + Math.random() * 0x888888;
			
			var aStartX :Number = 20 + FlxG.width * 0.8 * FlxG.random();
			var aStartY :Number = 20 + FlxG.height * 0.8 * FlxG.random();
			
			mConnection.connect(mMyName, { color: mMyColor, x: aStartX, y: aStartY, name: mMyName } );
			
			(FlxG.state as PlayState).hud.showMessage("Connecting", DEVKEY.length == 0 ? "ATTENTION! Use a valid key in DEVKEY at Multiplayer.as (line 38)" : "Please wait while we join the fun!", Number.MAX_VALUE);
		}
		
		protected function handleConnect(theUser:UserObject) :void {
			var aPlayer :Ship = new Ship(theUser.id, theUser.details.x, theUser.details.y, 0, "YOU");
			
			(FlxG.state as PlayState).player = aPlayer;
			(FlxG.state as PlayState).ships.add(aPlayer);
			
			FlxG.camera.follow(aPlayer, FlxCamera.STYLE_TOPDOWN);
			
			FlxG.log("I'm connected: " + theUser.name + ", total: " + mConnection.userCount); 
			
			(FlxG.state as PlayState).hud.hideMessages();
			(FlxG.state as PlayState).hud.updatePlayersCount(mConnection.userCount);
		}
		
		protected function handleUserAdded(theUser:UserObject) :void {
			var aShip :Ship = new Ship(theUser.id, theUser.details.x, theUser.details.y, theUser.details.color, theUser.details.name);
			(FlxG.state as PlayState).ships.add(aShip);
			
			mShips[theUser.id] = aShip;
			
			FlxG.log("User added: " + theUser.name + ", total users: " + mConnection.userCount);
			(FlxG.state as PlayState).hud.updatePlayersCount(mConnection.userCount);
		}
		
		protected function handleUserRemoved(theUser:UserObject) :void {
			(FlxG.state as PlayState).ships.remove(mShips[theUser.id]);
			
			mShips[theUser.id] = null;
			delete mShips[theUser.id];
			
			FlxG.log("User disconnected: " + theUser.name + ", total users: " + mConnection.userCount); 
			(FlxG.state as PlayState).hud.updatePlayersCount(mConnection.userCount);
		}
		
		public function sendPosition(theShip :Ship) :void	{
			mConnection.sendObject({op: OP_POSITION, x: theShip.x, y: theShip.y, angle: theShip.angle});
		}
		
		public function sendShot(theShip :Ship, theBulletType :Class) :void	{
			mConnection.sendObject({op: OP_SHOT, x: theShip.x, y: theShip.y, dx: theShip.direction.x, dy: theShip.direction.y, b: convertBulletClassToString(theBulletType)});
		}
		
		public function sendDie(theShip :Ship) :void	{
			mConnection.sendObject({op: OP_DIE, x: theShip.x, y: theShip.y});
		}
		
		protected function handleGetObject(theUserId :String, theData :Object) :void {
			var aOpCode :String = theData.op;
			
			switch(aOpCode) {
				case OP_POSITION:
					syncPosition(theUserId, theData);
					break;
					
				case OP_SHOT:
					syncPosition(theUserId, theData);
					mShips[theUserId].direction.x = theData.dx;
					mShips[theUserId].direction.y = theData.dy;

					(FlxG.state as PlayState).shoot(mShips[theUserId], convertBulletStringToClass(theData.b));
					break;
					
				case OP_DIE:
					mShips[theUserId].kill();
					break;
			}
		}
		
		private function syncPosition(theUserId :String, theData :Object) :void {
			mShips[theUserId].x  = theData.x;
			mShips[theUserId].y  = theData.y;
			
			if(theData.angle) {
				mShips[theUserId].angle = theData.angle;
			}
		}
		
		private function convertBulletClassToString(theType :Class) :String {
			var aRet :String;
			
			if (theType == SimpleBullet) { aRet = "S"; } else
			if (theType == Bomb) 		 { aRet = "B"; }

			return aRet;
		}
		
		private function convertBulletStringToClass(theType :String) :Class {
			var aRet :Class;
			
			if (theType == "S") { aRet = SimpleBullet; } else
			if (theType == "B") { aRet = Bomb; }
			
			return aRet;
		}
	}
}
