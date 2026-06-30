// Copyright (c) 2025 Huawei Device Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_HW file.
// Based on Camera.java originally written by
// Copyright 2013 The Flutter Authors.

import PrintingPlugin from './PrintingPlugin';
import { pdfService } from '@kit.PDFKit';
import fs from '@ohos.file.fs';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { print } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

const TAG = 'Printing';

export default class PrintingJob {
  private printing: PrintingPlugin;
  public index: number;
  private printingJobId: string | null = null;

  constructor(printing: PrintingPlugin, index: number) {
    this.printing = printing;
    this.index = index;
  }

  static printingInfo(): Map<string, boolean> {
    let data: Map<string, boolean> = new Map();
    data.set('directPrint', false);
    data.set('dynamicLayout', true);
    data.set('canPrint', true);
    data.set('canShare', true);
    data.set('canRaster', true);
    return data
  }

  public printPdf(name: string, printJob: PrintingJob, width: number, height: number, marginLeft: number,
    marginTop: number, marginRight: number, marginBottom: number) {
    this.printing.onLayout(printJob, width, height, marginLeft, marginTop, marginRight, marginBottom);
  }

  rasterPdf(data: Uint8Array, pages: number[], scale: number): void {
    let context = getContext(this);
    let applicationContext = context.getApplicationContext();
    let tempDir = applicationContext.tempDir;
    let filePath = tempDir + '/raster.pdf';

    // 文件存在则删除
    let res = fs.accessSync(filePath);
    if (res) {
      fs.unlinkSync(filePath);
    }

    let file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    fs.writeSync(file.fd, data.buffer);
    fs.closeSync(file);

    let pdfDocument = new pdfService.PdfDocument();
    let loadResult = pdfDocument.loadDocument(filePath, '');
    if (loadResult != pdfService.ParseResult.PARSE_SUCCESS) {
      Log.e(TAG, 'Failed to load pdf');
      return;
    }

    let pageCount = pages != null ? pages.length : pdfDocument.getPageCount();
    for (let index = 0; index < pageCount; index++) {
      let page = pdfDocument.getPage(index);
      let width = page.getWidth() * 2;
      let height = page.getHeight() * 2;
      let pdfMatrix: pdfService.PdfMatrix = new pdfService.PdfMatrix();
      pdfMatrix.x = 0;
      pdfMatrix.y = 0;
      pdfMatrix.rotate = 0;
      pdfMatrix.width = width;
      pdfMatrix.height = height
      let pixelMap = page.getCustomPagePixelMap(pdfMatrix, false, false);
      pixelMap.scale(scale, scale);
      // 原PixelMap颜色有问题，重新使用BGRA_8888输出PixelMap
      const imageInfo: image.ImageInfo = pixelMap.getImageInfoSync();
      const buffer: ArrayBuffer = new ArrayBuffer(pixelMap.getPixelBytesNumber());
      pixelMap.readPixelsToBufferSync(buffer);
      const opts: image.InitializationOptions = {
        editable: false,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: {
          height: imageInfo.size.height, width: imageInfo.size.width
        }
      };
      let newPixelMap = image.createPixelMapSync(buffer, opts);
      let pixelArrayBuffer: ArrayBuffer = new ArrayBuffer(newPixelMap.getPixelBytesNumber());
      newPixelMap.readPixelsToBufferSync(pixelArrayBuffer);
      let imageData: Uint8Array = new Uint8Array(pixelArrayBuffer);
      this.printing.onPageRasterized(this, imageData, width, height);
    }
    pdfDocument.releaseDocument();
    this.printing.onPageRasterEnd(this, null);
  }

  static sharePdf(context: Context, data: Uint8Array, name: string, subject: string, body: string,
    emails: string[]): void {
    let applicationContext = context.getApplicationContext();
    let tempDir = applicationContext.tempDir;
    let filePath = tempDir + '/' + name + '.pdf';

    // 文件存在则删除
    let res = fs.accessSync(filePath);
    if (res) {
      fs.unlinkSync(filePath);
    }

    let file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    fs.writeSync(file.fd, data.buffer);
    fs.closeSync(file);

    let uri = fileUri.getUriFromPath(filePath);
    let shareData: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.PDF,
      title: name,
      description: subject,
      uri: uri
    });

    let controller: systemShare.ShareController = new systemShare.ShareController(shareData);
    controller.show(context as common.UIAbilityContext, {
      previewMode: systemShare.SharePreviewMode.DETAIL,
      selectionMode: systemShare.SelectionMode.SINGLE
    });
  }

  cancelJob(message: string | null): void {
    if (this.printingJobId != null) {
      //cancelPrintJob是系统应用api
      //https://docs.openharmony.cn/pages/v4.1/zh-cn/application-dev/reference/apis-basic-services-kit/js-apis-print-sys.md#cancelprintjob-2
      //print.cancelPrintJob(this.printingJobId);  

      this.printingJobId = null;
    }
    this.printing.onCompleted(this, false, message);
  }

  setDocument(data: Uint8Array): void {
    let context = getContext(this);
    let applicationContext = context.getApplicationContext();
    let tempDir = applicationContext.tempDir;
    let filePath = tempDir + '/printing.pdf';

    // 文件存在则删除
    let res = fs.accessSync(filePath);
    if (res) {
      fs.unlinkSync(filePath);
    }

    let file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    fs.writeSync(file.fd, data.buffer);
    fs.closeSync(file);

    let _this = this;
    let printAdapter: print.PrintDocumentAdapter = {
      onStartLayoutWrite(jobId: string,
        oldAttrs: print.PrintAttributes,
        newAttrs: print.PrintAttributes,
        fd: number,
        writeResultCallback: (jobId: string, writeResult: print.PrintFileCreationState) => void): void {
        _this.printingJobId = jobId;

        let mgr = getContext(_this).resourceManager;
        if (mgr === undefined) {
          Log.e(TAG, 'print mrg is undefined');
          _this.printing.onCompleted(_this, false, 'mrg is undefined');
          return;
        }
        let stream: fs.Stream = fs.createStreamSync(filePath, 'r');
        const bufArray: ArrayBuffer[] = [];
        let totalLength = 0;
        let buf: ArrayBuffer = new ArrayBuffer(4096);
        let len: number = stream.readSync(buf);
        while (len !== 0) {
          totalLength += len;
          if (len < 4096) {
            buf = buf.slice(0, len);
            bufArray.push(buf);
            break;
          }
          bufArray.push(buf);
          buf = new ArrayBuffer(4096);
          len = stream.readSync(buf);
        }
        const contentBuf: Uint8Array = new Uint8Array(totalLength);
        let offset = 0;
        for (const bufArr of bufArray) {
          const uInt8Arr = new Uint8Array(bufArr);
          contentBuf.set(uInt8Arr, offset);
          offset += uInt8Arr.byteLength;
        }
        fs.writeSync(fd, contentBuf.buffer);
        writeResultCallback(jobId, print.PrintFileCreationState.PRINT_FILE_CREATED_UNRENDERED);
      },

      onJobStateChanged(jobId: string, state: print.PrintDocumentAdapterState): void {
        Log.d(TAG, 'print taskState: ' + JSON.stringify(state));
        _this.printingJobId = null;
        let success = state == print.PrintDocumentAdapterState.PRINT_TASK_SUCCEED;
        _this.printing.onCompleted(_this, success, null);
      }
    }
    let printAttributes: print.PrintAttributes = {
      copyNumber: 1,
      pageRange: {
        startPage: 0,
        endPage: 5,
        pages: []
      },
      pageSize: print.PrintPageType.PAGE_ISO_A3,
      directionMode: print.PrintDirectionMode.DIRECTION_MODE_AUTO,
      colorMode: print.PrintColorMode.COLOR_MODE_MONOCHROME,
      duplexMode: print.PrintDuplexMode.DUPLEX_MODE_NONE
    }
    print.print('printing_pdf', printAdapter, printAttributes, context);
  }
}