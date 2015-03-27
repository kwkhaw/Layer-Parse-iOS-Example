//
//  ATLPDataSource.m
//  LayerParseTest
//
//  Created by Kabir Mahal on 3/25/15.
//  Copyright (c) 2015 Layer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ATLPDataSource.h"
#import <Parse/Parse.h>
#import "PFUser+ATLParticipant.h"
#import <Bolts/Bolts.h>

@interface ATLPDataSource ()

@property (nonatomic) NSMutableDictionary *usersDictionary;

@end

@implementation ATLPDataSource

#pragma mark - Public Methods

+ (instancetype)sharedManager {
    static ATLPDataSource *sharedInstance = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        sharedInstance = [[ATLPDataSource alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        self.usersDictionary = [NSMutableDictionary new];
        [self loadLocalDataStore];
    }
    return self;
}

- (void)loadLocalDataStore {
    [self localQueryForAllUsersWithCompletion:^(NSArray *users) {
        for (PFUser *user in users) {
            [self.usersDictionary setObject:user forKey:user.objectId];
        }
    }];
}

#pragma mark Query Methods

- (void)localQueryForUserWithName:(NSString*)searchText completion:(void (^)(NSArray *participants))completion
{
    PFQuery *query = [PFUser query];
    [query fromLocalDatastore];
    [query whereKey:@"objectId" notEqualTo:[PFUser currentUser].objectId];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        NSMutableArray *contacts = [NSMutableArray new];
        for (PFUser *user in objects){
            if ([user.fullName rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [contacts addObject:user];
            }
        }
        if (completion) completion([NSArray arrayWithArray:contacts]);
    }];
}

- (void)localQueryForAllUsersWithCompletion:(void (^)(NSArray *users))completion
{
    PFQuery *query = [PFUser query];
    [query fromLocalDatastore];
    [query whereKey:@"objectId" notEqualTo:[PFUser currentUser].objectId];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (completion) completion(objects);
    }];
}

- (PFUser *)localQueryForUserID:(NSString *)userID
{
//    PFQuery *query = [PFUser query];
//    [query fromLocalDatastore];
//    PFUser *user = (PFUser*)[query getObjectWithId:userID];
    
    PFUser *user = (PFUser *)[self.usersDictionary objectForKey:userID];
    return user;
}

#pragma mark Data Creation Methods

- (void)createLocalParseUsersIfNeeded
{
    PFQuery *localQuery = [PFUser query];
    [localQuery fromLocalDatastore];
    [localQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (objects.count <= 1){
            [self createUserWithUsername:@"Bob"];
            [self createUserWithUsername:@"Jane"];
        }
    }];
}

- (void)createUserWithUsername:(NSString *)username
{
    PFUser *user = [PFUser new];
    user.username = username;
    user.objectId = [NSString stringWithFormat:@"ATLP%@", user.avatarInitials];
    [user pinInBackground];
    
    [self.usersDictionary setObject:user forKey:user.objectId];
}

- (void)queryAndLocallyStoreCloudUsers
{
    PFQuery *localQuery = [PFUser query];
    [localQuery fromLocalDatastore];
    [localQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        NSMutableArray *userIDS = [NSMutableArray new];
        
        for (PFUser *user in objects) {
            [userIDS addObject:user.objectId];
        }
        
        PFQuery *query = [PFUser query];
        [query whereKey:@"objectId" notContainedIn:userIDS];
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            if (!error) {
                for (PFUser *user in objects) {
                    [user pinInBackground];
                }
            } else {
                NSLog(@"Error querying Parse for Users with error: %@", error);
            }
        }];
    }];
}

- (NSString *)titleForConversation:(LYRConversation *)conversation
{
    NSMutableSet *participants = conversation.participants.mutableCopy;
    if ([participants containsObject:[PFUser currentUser].objectId]) {
        [participants removeObject:[PFUser currentUser].objectId];
    }
    
    NSString *title = @"";
    NSArray *titleParticipants = [participants allObjects];
    
    for (int i = 0; i <titleParticipants.count; i++) {
        PFUser *user = [[ATLPDataSource sharedManager] localQueryForUserID:[titleParticipants objectAtIndex:i]];
        if (i < titleParticipants.count-1) {
            title = [title stringByAppendingString:[NSString stringWithFormat:@"%@, ", user.firstName]];
        } else {
            title = [title stringByAppendingString:user.firstName];
        }
    }
    
    return title;
}

@end
