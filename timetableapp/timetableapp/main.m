#define COUCHDB_ID_KEY @"_id"
#define COUCHDB_REV_KEY @"_rev"
#define HTTP_METHOD_POST @"POST"
#define HTTP_METHOD_PUT @"PUT"

@implementation NSMutableDictionary (NSDictionary_FBTFCouchDB)

+ (id)dictionaryFromDocumentStore:(NSURL *)storeURL withIdentifier:(NSString *)identifer {
    if (!storeURL || !identifer) return nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:identifer relativeToURL:storeURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    NSError *error = nil;
    NSURLResponse *response = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error) {
        NSLog(@"Network Connection Error: %@", [error localizedDescription]);
        return nil;
    }
    // Couch uses UTF8 encoding for transfers
    NSString *jsonString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    if (!jsonString) return nil;
    error = nil;
    SBJSON *jsonParser = [[SBJSON alloc] init];
    id result = [jsonParser objectWithString:jsonString	allowScalar:YES error:&error];
    [jsonString release];
    [jsonParser release];
    if (error) {
        NSLog(@"JSON Parse Error: %@", [error localizedDescription]);
        return nil;
    }
    return result;
}
- (BOOL)persistInDocumentStore:(NSURL *)storeURL {
    // We do both inserts and updates in this method
    NSString *methodName;
    NSURL *requestURL;
    if ([self objectForKey:COUCHDB_ID_KEY]) {
        // this dictionary originated from the document database so update by including ID in URL
        methodName = HTTP_METHOD_PUT;
        requestURL = [NSURL URLWithString:[self objectForKey:COUCHDB_ID_KEY] relativeToURL:storeURL];
    } else {
        // This is a new Dictionary so we are inserting
        methodName = HTTP_METHOD_POST;
        requestURL = storeURL;
    }
    NSMutableURLRequest *aRequest = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    [aRequest setHTTPMethod:methodName];
    NSError *error = nil;
    SBJSON *jsonParser = [[SBJSON alloc] init];
    NSString *argsData = [jsonParser stringWithObject:self allowScalar:NO error:&error];
    if (error) {
        NSLog(@"JSON Serialisation Error: %@", [error localizedDescription]);
        return NO;
    }
    // Finish setting up the request and send to document store
    [aRequest setHTTPBody: [argsData dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLResponse *response = nil;
    error = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:aRequest returningResponse:&response error:&error];
    [aRequest release];
    // Now parse the results
    NSString *result = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    error = nil;
    NSDictionary *results = [jsonParser objectWithString:result allowScalar:NO error:&error];
    if (error || [results objectForKey:@"error"]) {
        // Something went wrong. report, clean up and return
        if (error) {
            NSLog(@"Can not parse results: %@", [error localizedDescription]);
        } else {
            NSLog(@"Database Error: %@", [results valueForKey:@"reason"]);
        }
        [jsonParser release];
        [result release];
        return NO;
    } else {
        // update the revision and the id (in case this is an insertion we do both)
        [self setValue:[results valueForKey:@"id"] forKey:COUCHDB_ID_KEY];
        [self setValue:[results valueForKey:@"rev"] forKey:COUCHDB_REV_KEY];
        [jsonParser release];
        [result release];
        return YES;
    }
}
@end