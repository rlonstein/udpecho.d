import std.conv : to;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import deimos.event2.event;
import std.experimental.logger;

void main(string[] args) {
  ushort port;
  event_base* eventLoop;
  
  if (args.length >= 2) {
    port = to!ushort(args[1]);
  }
  else {
    port = 4444;
  }
  infof("Will listen on port [%d]", port);

  scope(exit) {
    log("Cleaning up event loop...");
    if (eventLoop) {
      if (event_base_loopbreak(eventLoop) == 0) {
        error("Failed to break event loop!");
      }
      else {
        log("Event loop stopped");
      }
    }
    else {
      log("No event loop to clean up");
    }
  }
  
  try {
    infof("libevent version: %s", to!string(event_get_version()));
    eventLoop = event_base_new();
  }
  catch (Exception e) {
    errorf("Failed to create event loop: %s", e.msg);
    goto EXIT;
  }
 
  
  try {
    auto addr = new InternetAddress(port);
    UdpSocket listener;
    
    scope(exit) {
      logf("Cleaning up socket...");
      if (listener.isAlive) {
        listener.close();
      }
    }

    listener = new UdpSocket();
    assert(listener.isAlive);
    listener.bind(addr);
    logf("Bound socket to port [%d]", port);
    while(true) {
      ubyte[255] buf;
      Address remote_addr;
      long rc = listener.receiveFrom(buf, remote_addr);
      switch (rc) {
        case 0:
          // No data
          logf("No data received");
          break;
        case Socket.ERROR:
          // Error
          infof("Socket error: %s", listener.getErrorText());
          break;
        default:
          // Rec'd data
          logf("Echoing [%d] bytes to [%s]", rc, remote_addr);
          rc = listener.sendTo(buf[0..rc], remote_addr);
          if (rc == Socket.ERROR) {
            infof("Socket error: %s", listener.getErrorText());
          }
          else {
            logf("Sent [%d] bytes", rc);
          }
          break;
      }
    }
  }
  catch (SocketException e) {
    logf("SocketException: %s", e.msg);
  }
  catch (Exception e) {
    logf("Exception: %s", e.msg);
  }
 EXIT:
  logf("exiting");
}
