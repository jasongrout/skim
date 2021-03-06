//
//  SKVersionNumber.h
//  Skim
//
//  Created by Christiaan Hofman on 2/15/07.
/*
 This software is Copyright (c) 2007-2010
 Christiaan Hofman. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Christiaan Hofman nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SKVersionNumber.h"


@implementation SKVersionNumber

@synthesize originalVersionString, cleanVersionString, componentCount, releaseType;

+ (NSComparisonResult)compareVersionString:(NSString *)versionString toVersionString:(NSString *)otherVersionString;
{
    SKVersionNumber *versionNumber = [[self alloc] initWithVersionString:versionString];
    SKVersionNumber *otherVersionNumber = [[self alloc] initWithVersionString:otherVersionString];
    NSComparisonResult result = [versionNumber compare:otherVersionNumber];
    [versionNumber release];
    [otherVersionNumber release];
    return result;
}

// Initializes the receiver from a string representation of a version number.  The input string may have an optional leading 'v' or 'V' followed by a sequence of positive integers separated by '.'s.  Any trailing component of the input string that doesn't match this pattern is ignored.  If no portion of this string matches the pattern, nil is returned.
- (id)initWithVersionString:(NSString *)versionString;
{
    
    if (self = [super init]) {
        // Input might be from a NSBundle info dictionary that could be misconfigured, so check at runtime too
        if (versionString == nil || [versionString isKindOfClass:[NSString class]] == NO) {
            [self release];
            return nil;
        }
        
        originalVersionString = [versionString copy];
        releaseType = SKReleaseVersionType;
        
        NSMutableString *mutableVersionString = [[NSMutableString alloc] init];
        NSScanner *scanner = [[NSScanner alloc] initWithString:versionString];
        NSString *sep = @"";
        
        [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
        
        // ignore a leading "version" or "v", possibly followed by "-"
        if ([scanner scanString:@"version" intoString:NULL] || [scanner scanString:@"v" intoString:NULL])
            [scanner scanString:@"-" intoString:NULL];
        
        while ([scanner isAtEnd] == NO && sep != nil) {
            NSInteger component;
            
            if ([scanner scanInteger:&component] && component >= 0) {
            
                [mutableVersionString appendFormat:@"%@%ld", sep, (long)component];
                
                componentCount++;
                components = (NSInteger *)NSZoneRealloc(NSDefaultMallocZone(), components, sizeof(NSInteger) * componentCount);
                components[componentCount - 1] = component;
            
                if ([scanner isAtEnd] == NO) {
                    sep = nil;
                    if ([scanner scanString:@"." intoString:NULL] || [scanner scanString:@"-" intoString:NULL] || [scanner scanString:@"version" intoString:NULL] || [scanner scanString:@"v" intoString:NULL]) {
                        sep = @".";
                    }
                    if (releaseType == SKReleaseVersionType) {
                        if ([scanner scanString:@"alpha" intoString:NULL] || [scanner scanString:@"a" intoString:NULL]) {
                            releaseType = SKAlphaVersionType;
                            [mutableVersionString appendString:@"a"];
                        } else if ([scanner scanString:@"beta" intoString:NULL] || [scanner scanString:@"b" intoString:NULL]) {
                            releaseType = SKBetaVersionType;
                            [mutableVersionString appendString:@"b"];
                        } else if ([scanner scanString:@"development" intoString:NULL] || [scanner scanString:@"d" intoString:NULL]) {
                            releaseType = SKDevelopmentVersionType;
                            [mutableVersionString appendString:@"d"];
                        } else if ([scanner scanString:@"final" intoString:NULL] || [scanner scanString:@"f" intoString:NULL]) {
                            releaseType = SKReleaseCandidateVersionType;
                            [mutableVersionString appendString:@"f"];
                        } else if ([scanner scanString:@"release candidate" intoString:NULL] || [scanner scanString:@"rc" intoString:NULL] || [scanner scanString:@"f" intoString:NULL]) {
                            releaseType = SKReleaseCandidateVersionType;
                            [mutableVersionString appendString:@"rc"];
                        }
                        
                        if (releaseType != SKReleaseVersionType) {
                            // we scanned an "a", "b", "d", "f", or "rc"
                            componentCount++;
                            components = (NSInteger *)NSZoneRealloc(NSDefaultMallocZone(), components, sizeof(NSInteger) * componentCount);
                            components[componentCount - 1] = releaseType;
                            
                            sep = @"";
                            
                            // ignore a "." or "-"
                            if ([scanner scanString:@"." intoString:NULL] == NO)
                                [scanner scanString:@"-" intoString:NULL];
                        }
                    }
                }
            } else
                sep = nil;
        }
        
        if ([mutableVersionString isEqualToString:originalVersionString])
            cleanVersionString = [originalVersionString retain];
        else
            cleanVersionString = [mutableVersionString copy];
        
        [mutableVersionString release];
        [scanner release];
        
        if (componentCount == 0) {
            // Failed to parse anything and we don't allow empty version strings.  For now, we'll not assert on this, since people might want to use this to detect if a string begins with a valid version number.
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc;
{
    SKDESTROY(originalVersionString);
    SKDESTROY(cleanVersionString);
    SKZONEDESTROY(components);
    [super dealloc];
}

#pragma mark API

- (NSInteger)componentAtIndex:(NSUInteger)componentIndex;
{
    // This treats the version as a infinite sequence ending in "...0.0.0.0", making comparison easier
    if (componentIndex < componentCount)
        return components[componentIndex];
    return 0;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    if (NSShouldRetainWithZone(self, zone))
        return [self retain];
    else
        return [[[self class] allocWithZone:zone] initWithVersionString:originalVersionString];
}

#pragma mark Comparison

- (NSUInteger)hash;
{
    return [cleanVersionString hash];
}

- (BOOL)isEqual:(id)otherObject;
{
    if ([otherObject isMemberOfClass:[self class]] == NO)
        return NO;
    return [self compare:(SKVersionNumber *)otherObject] == NSOrderedSame;
}

- (NSComparisonResult)compare:(SKVersionNumber *)otherVersion;
{
    if (otherVersion == nil)
        return NSOrderedAscending;
    
    NSUInteger idx = 0, otherIdx = 0, otherCount = [otherVersion componentCount];
    while (idx < componentCount || otherIdx < otherCount) {
        NSInteger component = [self componentAtIndex:idx];
        NSInteger otherComponent = [otherVersion componentAtIndex:otherIdx];
        
        // insert zeros before matching possible a/d/b/rc components, e.g. to get 1b1 > 1.0a1
        if (component < 0 && otherComponent >= 0 && otherIdx < otherCount) {
            component = 0;
            otherIdx++;
        } else if (component >= 0 && otherComponent < 0 && idx < componentCount) {
            otherComponent = 0;
            idx++;
        } else {
            idx++;
            otherIdx++;
        }
        
        if (component < otherComponent)
            return NSOrderedAscending;
        else if (component > otherComponent)
            return NSOrderedDescending;
    }
    
    return NSOrderedSame;
}

@end
