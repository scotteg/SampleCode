//
//  ValueListsController.m
//  Angler Ally
//
//  Created by Scott Gardner on 8/21/12.
//  Copyright (c) 2012 Scott Gardner. All rights reserved.
//

#import "ValueListsController.h"

@implementation ValueListsController

- (void)seedInitialData
{
    UILocalizedIndexedCollation *currentCollation = [UILocalizedIndexedCollation currentCollation];
    __block NSString *language = [NSLocale preferredLanguages][0];
    NSArray *availableLocalizations = @[@"en", @"zh-Hans"];
    
    if (![availableLocalizations containsObject:language]) {
        if ([language isEqualToString:@"zh-Hant"]) {
            language = @"zh-Hans";
        } else {
            language = @"en";
        }
    }
    
    NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    NSArray *valueListEntities = [managedObjectModel entitiesForConfiguration:@"ValueLists"];
    
    [valueListEntities enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *entityName = [obj name];
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@_%@", entityName, language] ofType:@"plist"];
        NSArray *values = [[NSArray alloc] initWithContentsOfFile:plistPath];
        
        [values enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id object = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.managedObjectContext];
            [object setName:(NSString *)obj];
            NSInteger section = [currentCollation sectionForObject:object collationStringSelector:@selector(name)];
            [object setSectionKey:[currentCollation.sectionIndexTitles objectAtIndex:section]];
        }];
    }];
    
    if ([self saveManagedObjectContext:self.managedObjectContext]) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:YES forKey:@"ExistingUser"];
        [userDefaults setBool:YES forKey:@"UpdatedTo1.2"];
        [userDefaults synchronize];
    }
}

- (void)addSectionKeyToValueListEntities
{
    UILocalizedIndexedCollation *currentCollation = [UILocalizedIndexedCollation currentCollation];
    
    NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    NSArray *valueListEntities = [managedObjectModel entitiesForConfiguration:@"ValueLists"];
    
    __block NSFetchRequest *fetchRequest = [NSFetchRequest new];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:NO];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    [valueListEntities enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [fetchRequest setEntity:obj];
        NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
        NSError *error;
        
        if ([fetchedResultsController performFetch:&error]) {
            [fetchedResultsController.fetchedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSInteger section = [currentCollation sectionForObject:obj collationStringSelector:@selector(name)];
                [obj setSectionKey:[currentCollation.sectionIndexTitles objectAtIndex:section]];
            }];
        } else {
            FATAL_ERROR(error);
        }
    }];
    
    if ([self saveManagedObjectContext:self.managedObjectContext]) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:YES forKey:@"UpdatedTo1.2"];
        [userDefaults synchronize];
        [TestFlight localeVersionPassedCheckpoint:@"UPDATED_TO_1.2"];
    }
}

- (BOOL)saveManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSError *error;
    
    if ([managedObjectContext save:&error]) {
        return YES;
    } else {
        FATAL_ERROR(error);
        return NO;
    }
}

@end
