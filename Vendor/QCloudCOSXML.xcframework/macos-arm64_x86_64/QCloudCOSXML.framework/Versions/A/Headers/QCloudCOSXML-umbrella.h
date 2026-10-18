#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "QCloudCOSXMLVersion.h"
#import "QCloudCOSStorageClassEnum.h"
#import "QCloudCompleteMultipartUploadInfo.h"
#import "QCloudCopyObjectResult.h"
#import "QCloudInitiateMultipartUploadResult.h"
#import "QCloudListPartsResult.h"
#import "QCloudMultipartInfo.h"
#import "QCloudMultipartUploadInitiator.h"
#import "QCloudMultipartUploadOwner.h"
#import "QCloudMultipartUploadPart.h"
#import "QCloudUploadObjectResult.h"
#import "QCloudUploadPartResult.h"
#import "QCloudCOSTransferMangerService.h"
#import "QCloudCOSXMLService+Transfer.h"
#import "QCloudCOSXMLTransfer.h"
#import "QCloudAbortMultipfartUploadRequest.h"
#import "QCloudAppendObjectRequest.h"
#import "QCloudCompleteMultipartUploadRequest.h"
#import "QCloudCOSXMLCopyObjectRequest.h"
#import "QCloudCOSXMLDownloadObjectRequest.h"
#import "QCloudCOSXMLUploadObjectRequest.h"
#import "QCloudCOSXMLUploadObjectRequest_Private.h"
#import "QCloudGetObjectRequest+Custom.h"
#import "QCloudGetObjectRequest.h"
#import "QCloudHeadObjectRequest.h"
#import "QCloudInitiateMultipartUploadRequest.h"
#import "QCloudListMultipartRequest.h"
#import "QCloudPutObjectCopyRequest.h"
#import "QCloudPutObjectRequest+Custom.h"
#import "QCloudPutObjectRequest+CustomBuild.h"
#import "QCloudPutObjectRequest.h"
#import "QCloudUploadPartCopyRequest.h"
#import "QCloudUploadPartRequest+Custom.h"
#import "QCloudUploadPartRequest.h"
#import "NSString+RegularExpressionCategory.h"
#import "QCloudBizHTTPRequest+COSXML.h"
#import "QCloudCOSXMLEndPoint.h"
#import "QCloudCOSXMLService+Configuration.h"
#import "QCloudCOSXMLService+Private.h"
#import "QCloudCOSXMLService+Quality.h"
#import "QCloudCOSXMLService.h"
#import "QCloudCOSXMLServiceUtilities.h"
#import "QCloudLogManager.h"
#import "QCloudRequestData+COSXML.h"
#import "QCloudRequestData+COSXMLVersion.h"

FOUNDATION_EXPORT double QCloudCOSXMLVersionNumber;
FOUNDATION_EXPORT const unsigned char QCloudCOSXMLVersionString[];

