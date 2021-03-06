//
//  MidiIO.m
//  MidiIO Example
//
//  Created by Iyad Assaf on 08/09/2013.
//  Copyright (c) 2013 Iyad Assaf. All rights reserved.
//

#import "MidiIO.h"

@implementation MidiIO

#pragma mark variables
/* VARIABLES */

//Input variables
MIDIClientRef   inClient;
MIDIPortRef     inPort;
AudioUnit       instrumentUnit;
NSMutableArray *inputDevices;


//Output variables
MIDIClientRef           outClient;
MIDIPortRef             outputPort;
MIDIEndpointRef         midiOut;
NSMutableArray          *outputDevices;





#pragma mark Midi Input

void setupMidiInput()
{
    MIDIClientCreate(CFSTR("MidiIOInput"), NotificationProc, instrumentUnit, &inClient);
	MIDIInputPortCreate(inClient, CFSTR("Input port"), MIDIRead, instrumentUnit, &inPort);
    
    MIDIEndpointRef source = MIDIGetSource(0);
    
    
    CFStringRef endpointName = NULL;
    MIDIObjectGetStringProperty(source, kMIDIPropertyName, &endpointName);
    char endpointNameC[255];
    CFStringGetCString(endpointName, endpointNameC, 255, kCFStringEncodingUTF8);
    
    NSString *input = @"Launchpad";
    
    NSLog(@"Getting input from %@", input);
    
    //Read from this device - can read from many at the same time.
    MIDIPortConnectSource(inPort, source, (void*)[input UTF8String]);
    
}

//CoreMIDIutilities
#pragma mark CoreMIDI utilities

void NotificationProc (const MIDINotification  *message, void *refCon) {
	NSLog(@"MIDI Notify, MessageID=%d,", message->messageID);
}


static void	MIDIRead(const MIDIPacketList *pktlist, void *refCon, void *srcConnRefCon) {
    
    //Reads the source/device's name which is allocated in the MidiSetupWithSource function.
    const char *source = srcConnRefCon;
    
    //Extracting the data from the MIDI packets receieved.
    MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
	Byte note = packet->data[1] & 0x7F;
    Byte velocity = packet->data[2] & 0x7F;
    
    for (int i=0; i < pktlist->numPackets; i++) {
        
		Byte midiStatus = packet->data[0];
		Byte midiCommand = midiStatus >> 4;
        
		if ((midiCommand == 0x09) || //note on
			(midiCommand == 0x08)) { //note off
			
            MusicDeviceMIDIEvent(instrumentUnit, midiStatus, note, velocity, 0);
            
            NSLog(@"%s - NOTE : %d | %d", source, note, velocity);
            
            if(velocity != 0)
            {
                midiNoteOut(note, 14);
            } else {
                midiNoteOut(note, 121);
            }
        
            
            
		} else {
            
            NSLog(@"%s - CNTRL  : %d | %d", source, note, velocity);
            
        }
		
        //After we are done reading the data, move to the next packet.
        packet = MIDIPacketNext(packet);
	}
    
}

NSArray *listInputSources ()
{
    NSMutableArray *sourceArray = [[NSMutableArray alloc] init];
    unsigned long sourceCount = MIDIGetNumberOfSources();
    
    for (int i=0; i<sourceCount; i++) {
        MIDIEndpointRef source = MIDIGetSource(i);
        CFStringRef endpointName = NULL;
        MIDIObjectGetStringProperty(source, kMIDIPropertyName, &endpointName);
        char endpointNameC[255];
        CFStringGetCString(endpointName, endpointNameC, 255, kCFStringEncodingUTF8);
        
        NSString *NSEndpoint = [NSString stringWithUTF8String:endpointNameC];
        [sourceArray addObject: NSEndpoint];
    }
    return (NSArray *)sourceArray;
}


void disposeInput ()
{
    MIDIClientDispose(inClient);
    MIDIPortDispose(inPort);
}







#pragma mark Midi Output
/* OUTPUT */

void initMIDIOut()
{
    //Create the MIDI client and MIDI output port.
    MIDIClientCreate((CFStringRef)@"MidiIOOutput", NULL, NULL, &outClient);
    MIDIOutputPortCreate(outClient, (CFStringRef)@"Output port", &outputPort);
    
}

void midiNoteOut (int note, int velocity)
{
    //Set up the data to be sent
    const UInt8 noteOutData[] = {  0x90 , note , velocity};
    
    
    //Create a the packets that will be sent to the device.
    Byte packetBuffer[sizeof(MIDIPacketList)];
    MIDIPacketList *packetList = (MIDIPacketList *)packetBuffer;
    ByteCount size = sizeof(noteOutData);
    
    MIDIPacketListAdd(packetList,
                      sizeof(packetBuffer),
                      MIDIPacketListInit(packetList),
                      0,
                      size,
                      noteOutData);
    
    if(outputDevices.count)
    {
        //Send MIDI to all devices in the outputDevices array
        for(int i=0; i<outputDevices.count; i++)
        {
            MIDIEndpointRef outputEndpoint = MIDIGetDestination([listOutputSources() indexOfObject:[outputDevices objectAtIndex:i]]);
            MIDISend(outputPort, outputEndpoint, packetList);
        }
    } else {
        
        //Send to the default - 0
        MIDIEndpointRef outputEndpoint = MIDIGetDestination(0);
        MIDISend(outputPort, outputEndpoint, packetList);
        
    }
    
    
    
}


NSArray *listOutputSources ()
{
    NSMutableArray *outputArray = [[NSMutableArray alloc] init];
    unsigned long outputCount = MIDIGetNumberOfDestinations();
    
    for (int i=0; i<outputCount; i++) {
        MIDIEndpointRef source = MIDIGetDestination(i);
        CFStringRef endpointName = NULL;
        MIDIObjectGetStringProperty(source, kMIDIPropertyName, &endpointName);
        char endpointNameC[255];
        CFStringGetCString(endpointName, endpointNameC, 255, kCFStringEncodingUTF8);
//        NSLog(@"Output device %d - %s", i, endpointNameC);
        
        NSString *NSEndpoint = [NSString stringWithUTF8String:endpointNameC];
        [outputArray addObject: NSEndpoint];
    }
    return (NSArray *)outputArray;
}


void disposeOutput ()
{
    MIDIClientDispose(outClient);
    MIDIPortDispose(outputPort);
}





#pragma mark Obj-C methods

- (id)init
{
    self = [super init];
    if (self) {

        //For midi in:
        disposeInput();
        disposeOutput();
        
        setupMidiInput();
        
        //For midi out:
        initMIDIOut();
        
        for(int i=0; i<127; i++)
        {
            midiNoteOut(i, 127);
        }
        
        for(int i=0; i<127; i++)
        {
            midiNoteOut(i, 4);
        }

        
    }
    return self;
}




#pragma mark Obj-C Input methods

-(void)reInitializeMIDIInput
{
    disposeInput();
    setupMidiInput();
}


-(NSArray *)inputDevices
{
    return listInputSources();
}

-(void)addInputDevice:(NSString *)device
{
    [inputDevices addObject:device];
}

-(void)removeInputDevice:(NSString *)device
{
    [inputDevices removeObject:device];
}


-(void)disposeInputDevices
{
    disposeInput();
}





#pragma mark Obj-C Output methods


-(NSArray *)outputDevices
{
    return listOutputSources();
}

-(void)addOutputDevice:(NSString *)device
{
    NSLog(@"Added output device: %@", device);
    [outputDevices addObject:device];
}

-(void)removeOutputDevice:(NSString *)device
{
    [outputDevices removeObject:device];
}


-(void)clear
{
    for(int i=0; i<127; i++)
    {
        midiNoteOut(i, 127);
    }
    
    for(int i=0; i<127; i++)
    {
        midiNoteOut(i, 4);
    }

}

-(void)sendNote:(int)pitch :(int)vel;
{
    midiNoteOut(pitch, vel);
}


-(void)disposeOutputDevices
{
    disposeOutput();
}

@end
