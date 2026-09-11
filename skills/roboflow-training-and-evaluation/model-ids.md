# Roboflow Training Model IDs

Use these exact `model_id` values. Do not guess: wrong IDs cause training failures.

## Object Detection

| Family | model_id values |
|---|---|
| **RF-DETR** (named-model default) | `rfdetr-pico`, `rfdetr-nano`, `rfdetr-small`, `rfdetr-base`, `rfdetr-medium`, `rfdetr-large`, `rfdetr-xlarge`, `rfdetr-2xlarge` |
| YOLO26 | `yolo26n`, `yolo26s`, `yolo26m`, `yolo26l`, `yolo26x` |
| YOLOv12 | `yolov12n`, `yolov12s`, `yolov12m`, `yolov12l`, `yolov12x` |
| YOLOv11 | `yolov11n`, `yolov11s`, `yolov11m`, `yolov11l`, `yolov11x` |
| YOLOv8 | `yolov8n`, `yolov8s`, `yolov8m`, `yolov8l`, `yolov8x` |
| YOLO-NAS | `yolo_nas_s`, `yolo_nas_m`, `yolo_nas_l` |
| YOLOLite CPU | `yololite-edge-n`, `yololite-edge-s`, `yololite-edge-m`, `yololite-edge-l`, `yololite-edge-xl` |
| YOLOLite GPU | `yololite-n`, `yololite-s`, `yololite-m`, `yololite-l`, `yololite-xl` |

## Instance Segmentation

| Family | model_id values |
|---|---|
| **RF-DETR Seg** (named-model default) | `rfdetr-seg-nano`, `rfdetr-seg-small`, `rfdetr-seg-medium`, `rfdetr-seg-large`, `rfdetr-seg-xlarge`, `rfdetr-seg-2xlarge` |
| YOLO26 Seg | `yolo26n-seg`, `yolo26s-seg`, `yolo26m-seg`, `yolo26l-seg`, `yolo26x-seg` |
| YOLOv11 Seg | `yolov11n-seg`, `yolov11s-seg`, `yolov11m-seg`, `yolov11l-seg`, `yolov11x-seg` |
| YOLOv8 Seg | `yolov8n-seg`, `yolov8s-seg`, `yolov8m-seg`, `yolov8l-seg`, `yolov8x-seg` |
| SAM3 | `sam3-large` |

## Keypoint / Pose

| Family | model_id values |
|---|---|
| YOLO26 Pose | `yolo26n-pose`, `yolo26s-pose`, `yolo26m-pose`, `yolo26l-pose`, `yolo26x-pose` |
| YOLOv11 Pose | `yolov11n-pose`, `yolov11s-pose`, `yolov11m-pose`, `yolov11l-pose`, `yolov11x-pose` |
| YOLOv8 Pose | `yolov8n-pose`, `yolov8s-pose`, `yolov8m-pose`, `yolov8l-pose`, `yolov8x-pose` |

## Classification

| Family | model_id values |
|---|---|
| ViT | `vit-base-patch16-224-in21k` |
| ResNet | `resnet18`, `resnet34`, `resnet50`, `resnet101` |
| DINOv3 | `vit_base_patch16_dinov3.lvd1689m`, `vit_small_patch16_dinov3.lvd1689m` |

## Semantic Segmentation

| Family | model_id values |
|---|---|
| DeepLabV3+ | `deeplabv3plus` |

## Multimodal / VLM

| Family | model_id values |
|---|---|
| Qwen3.5 VL | `qwen3_5-2b-peft`, `qwen3_5-0.8b-peft` |
| Qwen3 VL | `qwen3vl-2b-instruct`, `qwen3vl-2b-instruct-peft` |
| SmolVLM | `smolvlm2-peft`, `smolvlm-256m-peft` |
| Florence 2 | `florence-2-base`, `florence-2-large`, `florence-2-base-peft`, `florence-2-large-peft` |
| PaliGemma 2 | `paligemma2-3b-pt-224`, `paligemma2-3b-pt-448`, `paligemma2-3b-pt-896`, `paligemma2-3b-pt-224-peft` |
| Qwen2.5 VL | `qwen25-vl-7b`, `qwen25-vl-7b-peft` |

## Other

| Model | model_id | Notes |
|---|---|---|
| SAM3 (zero-shot, workflows) | `sam3/sam3_final` | Always set `class_names`; no other props unless user asks |
| Custom / workspace | `workspace/model` or `dataset/version` | e.g., `construction-safety/2` |

## COCO 80 Classes (RF-DETR coverage)

person, bicycle, car, motorcycle, airplane, bus, train, truck, boat, traffic light, fire hydrant, stop sign, parking meter, bench, bird, cat, dog, horse, sheep, cow, elephant, bear, zebra, giraffe, backpack, umbrella, handbag, tie, suitcase, frisbee, skis, snowboard, sports ball, kite, baseball bat, baseball glove, skateboard, surfboard, tennis racket, bottle, wine glass, cup, fork, knife, spoon, bowl, banana, apple, sandwich, orange, broccoli, carrot, hot dog, pizza, donut, cake, chair, couch, potted plant, bed, dining table, toilet, tv, laptop, mouse, remote, keyboard, cell phone, microwave, oven, toaster, sink, refrigerator, book, clock, vase, scissors, teddy bear, hair drier, toothbrush.
