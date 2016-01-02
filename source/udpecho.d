import std.conv : to;
import std.socket : InternetAddress, UdpSocket, SocketException;
import deimos.event2.event;
import std.experimental.logger;

void main(string[] args) {
  ushort port;
  UdpSocket listener;
  event_base* eventLoop;
  event* ev;

  if (args.length >= 2) {
    port = to!ushort(args[1]);
  }
  else {
    port = 4444;
  }
  infof("Will listen on port [%d]", port);

  // Set up socket and its clean-up
  scope(exit) {
    logf("Cleaning up socket...");
    if (listener.isAlive) {
      listener.close();
    }
  }

  try {
    listener = new UdpSocket();
  }
  catch (SocketException e) {
    errorf("SocketException: %s", e.msg);
    goto EXIT;
  }

  if (listener.isAlive) {
    InternetAddress addr = new InternetAddress(port);
    listener.bind(addr);
    logf("Bound socket to port [%d]", port);

    // Set up event loop and its eventual clean-up
    scope(exit) {
      log("Cleaning up event loop...");
      if (eventLoop) {
        if (event_base_loopbreak(eventLoop) == 0) {
          error("Failed to break event loop!");
        }
        else {
          log("Event loop stopped");
          event_base_free(eventLoop);
          log("Event loop freed");
        }
      }
      else {
        log("No event loop to clean up");
      }
    }

    infof("libevent version: %s", to!string(event_get_version()));
    eventLoop = event_base_new();

    // Grab underlying socket and register callback with libevent
    scope(exit) {
      log("Deallocating event");
      event_free(ev);
    }

    ev = event_new(eventLoop, cast(int)listener.handle(), cast(short)EV_READ|EV_PERSIST, &cb_echo, null);
    event_add(ev, null);
    log("Created event and added to loop");

    // Finally, start the dispatch loop
    log("Starting event loop");
    event_base_dispatch(eventLoop);
  }
  else {
    error("Failed to create socket, aborting");
  }
 EXIT:
  info("Main exiting...");
}


extern (C) void cb_echo(evutil_socket_t sockfd, short evflags, void* arg) {
  import std.socket : Socket, Address, SocketException, socket_t;

  log("entered callback");

  // re-wrap in a Socket obj, more convenient than a raw fd, then echo
  try {
    Socket socket = new Socket(cast(socket_t)sockfd, std.socket.AddressFamily.INET);
    ubyte[255] buf;
    Address remote_addr;
    long recv = socket.receiveFrom(buf, remote_addr);
    switch (recv) {
      case 0:
        // No data
        logf("No data received");
        break;
      case Socket.ERROR:
        // Error
        infof("Socket error: %s", socket.getErrorText());
        break;
      default:
        // Rec'd data, echo it back
        logf("Echoing [%d] bytes to [%s]", recv, remote_addr);
        long sent = socket.sendTo(buf[0..recv], remote_addr);
        if (sent == Socket.ERROR) {
          infof("Socket error: %s", socket.getErrorText());
        }
        else {
          logf("Sent [%d] of [%d] bytes", sent, recv);
        }
        break;
    }
  }
  catch (SocketException e) {
    errorf("SocketException: %s", e.msg);
  }
 cb_echo_exit:
  log("leaving callback");
}
