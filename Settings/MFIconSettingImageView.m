//
//  MFIconSettingImageView.m
//  MacFusion2
//
//  Created by Michael Gorbach on 3/19/08.
//  Copyright 2008 Michael Gorbach. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "MFIconSettingImageView.h"
#import "MFClientFS.h"
#import <QuartzCore/QuartzCore.h>
#import "MGNSImage.h"

@implementation MFIconSettingImageView
+ (void)initialize
{
	[self exposeBinding: @"fs"];
}

- (id)initWithFrame:(NSRect)frame
{
	if (self = [super initWithFrame: frame])
	{
		// MFLogS(self, @"Registering for types");
		[self registerForDraggedTypes:
		 [NSArray arrayWithObjects: NSFilenamesPboardType, (NSString*)kUTTypeAppleICNS,
		  nil] ];
		 dragHighlight = NO;
	}
	
	return self;
}

- (void)recalcImages
{
	NSRect rect = [self bounds];
	NSImage* imageToDraw = [fs iconImage];
	normalImage = [[[imageToDraw ciImageRepresentation] ciImageByScalingToSize:
							 NSMakeSize(rect.size.width, rect.size.height)] flippedImage];
	CIFilter* bloomFilter = [CIFilter filterWithName:@"CIBloom"];
	[bloomFilter setValue:[NSNumber numberWithFloat:2.5] forKey:@"inputRadius"];
	[bloomFilter setValue:[NSNumber numberWithFloat:0.7] forKey:@"inputIntensity"];
	[bloomFilter setValue: normalImage forKey: @"inputImage"];
	selectedImage = [bloomFilter valueForKey:@"outputImage"];
	[self setNeedsDisplay: YES];
}

- (void)awakeFromNib
{
	[self addObserver:self
		   forKeyPath:@"fs.imagePath"
			  options:NSKeyValueObservingOptionNew
			  context:self];
}

- (void)drawRect:(NSRect)rect 
{
	// MFLogS(self, @"Image is %@", image);
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	CIImage* imageToDraw = ([[self window] firstResponder] == self) ? selectedImage : normalImage;
	
	if (dragHighlight)
	{
		[[NSColor darkGrayColor] set];
		[NSBezierPath setDefaultLineWidth: 3.0];
		[NSBezierPath strokeRect: rect];
	}
	
	[imageToDraw drawInRect:rect
				   fromRect:NSMakeRect(0, 0, rect.size.width, rect.size.height)
				  operation:NSCompositeSourceOver
				   fraction:1.0];
}

# pragma mark C&P
- (void)setImageFromPasteboard:(NSPasteboard*)pb
{
	// MFLogS(self, @"Pasting pb types %@", [pb types]);
	NSImage* imageToSet = nil;
	
	// Try getting filename data first
	NSArray* fileNameData = [pb propertyListForType: NSFilenamesPboardType];
	NSString* firstFileName = [fileNameData objectAtIndex: 0];
	if ([firstFileName isLike:@"*.icns"])
	{
		NSImage* iconImage = [[NSImage alloc] initWithContentsOfFile: firstFileName];
		if (iconImage)
			imageToSet = iconImage;
	}
	
	if(!imageToSet)
	{
		NSData* icnsData = [pb dataForType: (NSString*)kUTTypeAppleICNS];
		NSImage* icnsImage = [[NSImage alloc] initWithData: icnsData];
		if (icnsImage)
			imageToSet = icnsImage;
	}
	
	if (imageToSet)
	{
		[self.fs setIconImage: imageToSet];
		[self setNeedsDisplay: YES];
	}
}



- (void)paste:(id)paste
{
	[self setImageFromPasteboard: [NSPasteboard generalPasteboard]];
}

# pragma mark NSResponder
- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	[self setNeedsDisplay: YES];
	return YES;
}

- (void)resignFirstResponder
{
	[self setNeedsDisplay: YES];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
	// MFLogS(self, @"Validating %@", item);
	if ([item action] == @selector(paste:))
	{
		if ([[NSPasteboard generalPasteboard] dataForType: (NSString*)kUTTypeAppleICNS])
			return YES;
		
		NSArray* fileNames = [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType];
		if (fileNames && [[fileNames objectAtIndex: 0] isLike: @"*.icns"])
			return YES;
		
		return NO;
	}
	
	return NO;
}

- (void)keyDown:(NSEvent*)event
{
	if ([event keyCode] == 117)
	{
		[fs setIconImage: nil];
		[self setNeedsDisplay: YES];
	}
	else
	{
		[super keyDown: event];
	}
}

# pragma mark D&D
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pb = [sender draggingPasteboard];
	NSString* type = [pb availableTypeFromArray: [NSArray arrayWithObjects: NSFilenamesPboardType,
												  (NSString*)kUTTypeAppleICNS, nil]];
	if (type)
	{
		dragHighlight = YES;
		[self setNeedsDisplay: YES];
		return NSDragOperationCopy;
	}
	
	return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return NSDragOperationCopy;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	dragHighlight = NO;
	[self setNeedsDisplay: YES];
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	[self setImageFromPasteboard: [sender draggingPasteboard]];
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	dragHighlight = NO;
	[self setNeedsDisplay: YES];
}

# pragma mark KVO
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
						 change:(NSDictionary *)change context:(void *)context
{
	// MFLogS(self, @"Observe triggered");
    if (context == self) {
		[self recalcImages];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

@synthesize fs;
@end
