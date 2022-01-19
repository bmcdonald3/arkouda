/* arkouda server
backend chapel program to mimic ndarray from numpy
This is the main driver for the arkouda server */

use FileIO;
use Security;
use ServerConfig;
use Time only;
use ZMQ only;
use Memory;
use FileSystem;
use IO;
use Logging;
use Path;
use MultiTypeSymbolTable;
use MultiTypeSymEntry;
use MsgProcessing;
use GenSymIO;
use Reflection;
use SymArrayDmap;
use ServerErrorStrings;
use Message;

use CommandMap, ServerRegistration;

private config const logLevel = ServerConfig.logLevel;
const asLogger = new Logger(logLevel);

proc initArkoudaDirectory() {
    var arkDirectory = '%s%s%s'.format(here.cwd(), pathSep,'.arkouda');
    initDirectory(arkDirectory);
    return arkDirectory;
}

proc main() {
 
    proc printServerSplashMessage(token: string, arkDirectory: string) throws {
        var verMessage = "arkouda server version = %s".format(arkoudaVersion);
        var dirMessage = ".arkouda directory %s".format(arkDirectory);
        var memLimMessage =  "memory limit = %i".format(getMemLimit());
        var memUsedMessage = "bytes of memory used = %i".format(getMemUsed());
        var serverMessage: string;
    
        const buff = '                         ';
    
        proc adjustMsg(msg: string) throws {
            if msg.size % 2 != 0 {
                return msg + ' ';
            } else {
                return msg;
            }   
        }
    
        proc generateBuffer(longSegment: string, shortSegment: string) : string {
            var buffSize = (longSegment.size - shortSegment.size)/2 - 2;
            var buffer: string;
            var counter = 0;
        
            while counter <= buffSize {
                buffer+=' ';
                counter+=1;
            }           
            return buffer;
        }
    
        if token.isEmpty() {
            serverMessage = "server listening on tcp://%s:%t".format(serverHostname, 
                                                                 ServerPort);
        } else {
            serverMessage = "server listening on tcp://%s:%i?token=%s".format(serverHostname, 
                                                                 ServerPort, token);
        }
        
        doRegister();
        serverMessage = adjustMsg(serverMessage);      
        serverMessage = "%s %s %s".format(buff,serverMessage,buff);
        
        var vBuff = generateBuffer(serverMessage,verMessage);
        verMessage = adjustMsg(verMessage);
        verMessage = "*%s %s %s*".format(vBuff,verMessage,vBuff);

        var mlBuff = generateBuffer(serverMessage,memLimMessage);
        memLimMessage = adjustMsg(memLimMessage);
        memLimMessage = "*%s %s %s*".format(mlBuff,memLimMessage,mlBuff);

        var muBuff = generateBuffer(serverMessage,memUsedMessage);
        memUsedMessage = adjustMsg(memUsedMessage);
        memUsedMessage = "*%s %s %s*".format(muBuff,memUsedMessage,muBuff);
        
        var blankBuffer: string;
        var counter = 0;
        
        while counter < serverMessage.size {
            blankBuffer+=' ';
            counter+=1;
        }

        var blankLine = '*%s*'.format(blankBuffer);
        
        var tag = '*';
        counter = 0;
        
        while counter <= serverMessage.size {
            tag+='*';
            counter+=1;
        }

        writeln();
        writeln();
        writeln(tag);
        writeln(tag);
        writeln(blankLine);
        writeln('*%s*'.format(serverMessage));
        writeln(verMessage);
        if (memTrack) {
            writeln(memLimMessage);
            writeln(memUsedMessage);
        }
        writeln(blankLine);
        writeln(tag);
        writeln(tag);
        writeln();
        writeln();
        stdout.flush();
    }

    const arkDirectory = initArkoudaDirectory();

    var st = new owned SymTab();
    var shutdownServer = false;
    var serverToken : string;
    var serverMessage : string;

    // create and connect ZMQ socket
    var context: ZMQ.Context;
    var socket : ZMQ.Socket = context.socket(ZMQ.REP);

    // configure token authentication if applicable
    if authenticate {
        serverToken = getArkoudaToken('%s%s%s'.format(arkDirectory, pathSep, 'tokens.txt'));
    }

    printServerSplashMessage(serverToken,arkDirectory);

    socket.bind("tcp://*:%t".format(ServerPort));
    
    asLogger.debug(getModuleName(), getRoutineName(), getLineNumber(),
                               "initialized the .arkouda directory %s".format(arkDirectory));
    
    createServerConnectionInfo();

    var reqCount: int = 0;
    var repCount: int = 0;

    var t1 = new Time.Timer();
    t1.clear();
    t1.start();

    /*
    Following processing of incoming message, sends a message back to the client.

    :arg repMsg: either a string or bytes to be sent
    */
    proc sendRepMsg(repMsg: ?t) throws where t==string || t==bytes {
        repCount += 1;
        if trace {
          if t==bytes {
              asLogger.info(getModuleName(),getRoutineName(),getLineNumber(),
                                                        "repMsg: <binary-data>");
          } else {
              asLogger.info(getModuleName(),getRoutineName(),getLineNumber(), 
                                                        "repMsg: %s".format(repMsg));
          }
        }
        socket.send(repMsg);
    }

    /*
    Compares the token submitted by the user with the arkouda_server token. If the
    tokens do not match, or the user did not submit a token, an ErrorWithMsg is thrown.    

    :arg token: the submitted token string
    */
    proc authenticateUser(token : string) throws {
        if token == 'None' || token.isEmpty() {
            throw new owned ErrorWithMsg("Error: access to arkouda requires a token");
        }
        else if serverToken != token {
            throw new owned ErrorWithMsg("Error: token %s does not match server token, check with server owner".format(token));
        }
    } 

    /*
     * Converts the incoming request JSON string into RequestMsg object.
     */
    proc extractRequest(request : string) : RequestMsg throws {
        var rm = new RequestMsg();
        deserialize(rm, request);
        return rm;
    }
    
    /*
    Sets the shutdownServer boolean to true and sends the shutdown command to socket,
    which stops the arkouda_server listener thread and closes socket.
    */
    proc shutdown(user: string) {
        shutdownServer = true;
        repCount += 1;
        socket.send(serialize(msg="shutdown server (%i req)".format(repCount), 
                         msgType=MsgType.NORMAL,msgFormat=MsgFormat.STRING, user=user));
    }
    
    while !shutdownServer {
        // receive message on the zmq socket
        var reqMsgRaw = socket.recv(bytes);

        reqCount += 1;

        var s0 = t1.elapsed();
        
        /*
         * Separate the first tuple, which is a string binary containing the JSON binary
         * string encapsulating user, token, cmd, message format and args from the 
         * remaining payload.
         */
        var (rawRequest, _) = reqMsgRaw.splitMsgToTuple(b"BINARY_PAYLOAD",2);
        var payload = if reqMsgRaw.endsWith(b"BINARY_PAYLOAD") then socket.recv(bytes) else b"";
        var user, token, cmd: string;

        // parse requests, execute requests, format responses
        try {
            /*
             * Decode the string binary containing the JSON-formatted request string. 
             * If there is an error, discontinue processing message and send an error
             * message back to the client.
             */
            var request : string;

            try! {
                request = rawRequest.decode();
            } catch e: DecodeError {
                asLogger.error(getModuleName(),getRoutineName(),getLineNumber(),
                       "illegal byte sequence in command: %t".format(
                                          rawRequest.decode(decodePolicy.replace)));
                sendRepMsg(serialize(msg=unknownError(e.message()),msgType=MsgType.ERROR,
                                                 msgFormat=MsgFormat.STRING, user="Unknown"));
            }

            // deserialize the decoded, JSON-formatted cmdStr into a RequestMsg
            var msg: RequestMsg  = extractRequest(request);
            user   = msg.user;
            token  = msg.token;
            cmd    = msg.cmd;
            var format = msg.format;
            var args   = msg.args;

            /*
             * If authentication is enabled with the --authenticate flag, authenticate
             * the user which for now consists of matching the submitted token
             * with the token generated by the arkouda server
             */ 
            if authenticate {
                authenticateUser(token);
            }

            if (trace) {
              try {
                if (cmd != "array") {
                  asLogger.info(getModuleName(), getRoutineName(), getLineNumber(),
                                                     ">>> %t %t".format(cmd, args));
                } else {
                  asLogger.info(getModuleName(), getRoutineName(), getLineNumber(),
                                                     ">>> %s [binary data]".format(cmd));
                }
              } catch {
                // No action on error
              }
            }

            // If cmd is shutdown, don't bother generating a repMsg
            if cmd == "shutdown" {
                shutdown(user=user);
                if (trace) {
                    asLogger.info(getModuleName(),getRoutineName(),getLineNumber(),
                                         "<<< shutdown initiated by %s took %.17r sec".format(user, 
                                                   t1.elapsed() - s0));
                }
                break;
            }

            /*
             * For messages that return a string repTuple is filled. For binary
             * messages the message is sent directly to minimize copies.
             */
            var repTuple: MsgTuple;
            
            if commandMap.contains(cmd) then
              repTuple = commandMap.getBorrowed(cmd)(cmd, args, st);
            else {
              select cmd
              {
                  when "array"             {repTuple = arrayMsg(cmd, args, payload, st);}
                  when "tondarray"         {
                    var binaryRepMsg = tondarrayMsg(cmd, args, st);
                    sendRepMsg(binaryRepMsg);
                  }
                  // TODO: this requires SegmentedMsg to be in included
                  // in the build always; not sure best way to handle
                  when "segStr-tondarray"  {
                    use SegmentedMsg;
                    var binaryRepMsg = segStrTondarrayMsg(cmd, args, st);
                    sendRepMsg(binaryRepMsg);
                  }

                  when "create"            {repTuple = createMsg(cmd, args, st);}
                  when "delete"            {repTuple = deleteMsg(cmd, args, st);}
                  when "arange"            {repTuple = arangeMsg(cmd, args, st);}
                  when "linspace"          {repTuple = linspaceMsg(cmd, args, st);}
                  when "set"               {repTuple = setMsg(cmd, args, st);}
                  when "info"              {repTuple = infoMsg(cmd, args, st);}
                  when "str"               {repTuple = strMsg(cmd, args, st);}
                  when "repr"              {repTuple = reprMsg(cmd, args, st);}
                  when "getconfig"         {repTuple = getconfigMsg(cmd, args, st);}
                  when "getmemused"        {repTuple = getmemusedMsg(cmd, args, st);}
                  when "clear"             {repTuple = clearMsg(cmd, args, st);}               
                  when "connect" {
                      if authenticate {
                          repTuple = new MsgTuple("connected to arkouda server tcp://*:%i as user %s with token %s".format(
                                                            ServerPort,user,token), MsgType.NORMAL);
                      } else {
                          repTuple = new MsgTuple("connected to arkouda server tcp://*:%i".format(ServerPort), 
                                                                                          MsgType.NORMAL);
                      }
                  }
                  when "disconnect" {
                      repTuple = new MsgTuple("disconnected from arkouda server tcp://*:%i".format(ServerPort), 
                                                                     MsgType.NORMAL);
                  }
                  when "noop" {
                      repTuple = new MsgTuple("noop", MsgType.NORMAL);
                  }
                  when "ruok" {
                      repTuple = new MsgTuple("imok", MsgType.NORMAL);
                  }
                  otherwise {
                      repTuple = new MsgTuple("Unrecognized command: %s".format(cmd), MsgType.ERROR);
                      asLogger.error(getModuleName(),getRoutineName(),getLineNumber(),repTuple.msg);
                  }
              }
           }

            /*
             * If the reply message is a string send it now
             */          
            if !repTuple.msg.isEmpty() {
                sendRepMsg(serialize(msg=repTuple.msg,msgType=repTuple.msgType,
                                                              msgFormat=MsgFormat.STRING, user=user));
            }

            /*
             * log that the request message has been handled and reply message has been sent along with 
             * the time to do so
             */
            if trace {
                asLogger.info(getModuleName(),getRoutineName(),getLineNumber(), 
                                              "<<< %s took %.17r sec".format(cmd, t1.elapsed() - s0));
            }
            if (trace && memTrack) {
                asLogger.info(getModuleName(),getRoutineName(),getLineNumber(),
                    "bytes of memory used after command %t".format(getMemUsed():uint * numLocales:uint));
            }
        } catch (e: ErrorWithMsg) {
            // Generate a ReplyMsg of type ERROR and serialize to a JSON-formatted string
            sendRepMsg(serialize(msg=e.msg,msgType=MsgType.ERROR, msgFormat=MsgFormat.STRING, 
                                                        user=user));
            if trace {
                asLogger.error(getModuleName(),getRoutineName(),getLineNumber(),
                    "<<< %s resulted in error %s in  %.17r sec".format(cmd, e.msg, t1.elapsed() - s0));
            }
        } catch (e: Error) {
            // Generate a ReplyMsg of type ERROR and serialize to a JSON-formatted string
            var errorMsg = e.message();
            
            if errorMsg.isEmpty() {
                errorMsg = "unexpected error";
            }

            sendRepMsg(serialize(msg=errorMsg,msgType=MsgType.ERROR, 
                                                         msgFormat=MsgFormat.STRING, user=user));
            if trace {
                asLogger.error(getModuleName(), getRoutineName(), getLineNumber(), 
                    "<<< %s resulted in error: %s in %.17r sec".format(cmd, e.message(),
                                                                                 t1.elapsed() - s0));
            }
        }
    }

    t1.stop();

    deleteServerConnectionInfo();

    asLogger.info(getModuleName(), getRoutineName(), getLineNumber(),
               "requests = %i responseCount = %i elapsed sec = %i".format(reqCount,repCount,
                                                                                 t1.elapsed()));
}

/*
Creates the serverConnectionInfo file on arkouda_server startup
*/
proc createServerConnectionInfo() {
    use IO;
    if !serverConnectionInfo.isEmpty() {
        try! {
            var w = open(serverConnectionInfo, iomode.cw).writer();
            w.writef("%s %t\n", serverHostname, ServerPort);
        }
    }
}

/*
Deletes the serverConnetionFile on arkouda_server shutdown
*/
proc deleteServerConnectionInfo() {
    use FileSystem;
    try {
        if !serverConnectionInfo.isEmpty() {
            remove(serverConnectionInfo);
        }
    } catch fnfe : FileNotFoundError {
        asLogger.error(getModuleName(),getRoutineName(),getLineNumber(),
                              "The serverConnectionInfo file was not found %s".format(fnfe.message()));
    } catch e : Error {
        asLogger.error(getModuleName(),getRoutineName(),getLineNumber(),
                              "Error in deleting serverConnectionInfo file %s".format(e.message()));    
    }
}
