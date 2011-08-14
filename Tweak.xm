/**
 * Name: Bug Fix: Duplicate Icons
 * Type: iOS SpringBoard extension (MobileSubstrate-based)
 * Desc: Prevent SpringBoard from resetting icon layout when it detects duplicate icons.
 *
 *       Any time that SpringBoard lays out icons pages (such as at startup),
 *       it calls SBIconModel's createIconLists method. This method checks the
 *       icon state to ensure that it contains no duplicate entries (icons).
 *       If any duplicates are detected, it solves the problem by deleting
 *       the icon state, which causes the icon layout to be reset.
 *
 *       This extension attempts to fix the problem by actually removing the
 *       duplicates and preventing the icon state from being deleted.
 *
 *       Possible causes for duplicate icons:
 *       - "Stuck Pages" bug in SpringBoard
 *           - This bug can be prevented by via "Bug Fix: Stuck Pages":
 *             http://github.com/ashikase/BugFix_StuckPages
 *       - Bugs in 3rd-party SpringBoard extensions
 *       - Using 3rd-party SpringBoard extensions in ways they were not designed
 *         to be used, such as by using them on unsupported devices/firmware,
 *         or by using them together with extensions with which they are known
 *         to conflict.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 *
 * Last-modified: 2011-08-14 22:51:19
 */


@interface SBIconModel : NSObject
- (id)_iconState;
- (id)iconStatePath;
- (void)noteIconStateChangedExternally;
@end

static BOOL duplicateWasFound_ = NO;

// Remove duplicate items from a group of icon lists
static NSArray *removeDupes(NSArray *iconLists, NSMutableArray *knownIdentifiers)
{
    NSMutableArray *result = [NSMutableArray array];
    
    Class $NSDictionary = [NSDictionary class];
    for (NSArray *list in iconLists) {
        NSMutableArray *newList = [[NSMutableArray alloc] init];
        for (id item in list) {
            if ([item isKindOfClass:$NSDictionary]) {
                // Is a folder
                NSMutableDictionary *newFolder = [item mutableCopy];
                [newFolder setObject:removeDupes([item objectForKey:@"iconLists"], knownIdentifiers) forKey:@"iconLists"];
                [newList addObject:newFolder];
                [newFolder release];
            } else {
                // Is an icon (NSString)
                if (![knownIdentifiers containsObject:item]) {
                    // Not a duplicate
                    [newList addObject:item];
                    [knownIdentifiers addObject:item];
                } else {
                    // Record that at least one duplicate was found
                    duplicateWasFound_ = YES;
                }
            }
        }
        [result addObject:newList];
        [newList release];
    }

    return result;
}

%hook SBIconModel

- (void)deleteIconState
{
    // Get the current icon state
    NSMutableDictionary *iconState = [[self _iconState] mutableCopy];
    if (iconState != nil) {
        // Create an array to use for tracking identifiers
        NSMutableArray *knownIdentifiers = [[NSMutableArray alloc] init];

        // Remove duplicates from dock
        NSArray *dock = [iconState objectForKey:@"buttonBar"];
        if (dock != nil) {
            // NOTE: removeDupes() expects an array within an array;
            //       must wrap dock in an array.
            dock = [NSArray arrayWithObject:dock];
            dock = [removeDupes(dock, knownIdentifiers) lastObject];
            [iconState setObject:dock forKey:@"buttonBar"];
        }

        // Remove duplicates from pages
        NSArray *iconLists = [iconState objectForKey:@"iconLists"];
        if (iconLists != nil) {
            iconLists = removeDupes(iconLists, knownIdentifiers);
            [iconState setObject:iconLists forKey:@"iconLists"];
        }

        if (duplicateWasFound_) {
            // Write updated icon state to file
            [iconState writeToFile:[self iconStatePath] atomically:YES];

            // Relayout the icons
            [self noteIconStateChangedExternally];

            // Reset the flag in case deleteIconState is called again later
            duplicateWasFound_ = NO;
        } else {
            // No duplicate icons were found; assume that deleteIconState
            // was called for another reason.
            // NOTE: Currently it is believed that deleteIconState is not
            //       called for any other reason; however, better to be safe.
            %orig;
        }

        // Cleanup
        [knownIdentifiers release];
        [iconState release];
    } else {
        // Was unable to retrieve/copy icon state
        // NOTE: Currently it is believed that this will never occur; however,
        //       if it did, it might indicate that the icon layout file is
        //       corrupt, and thus really should be deleted.
        %orig;
    }
}

%end

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
