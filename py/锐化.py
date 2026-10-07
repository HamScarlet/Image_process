import cv2
import numpy as np 

def laplacian_shapening(input_path,output_path):
    image = cv2.imread(input_path)
    if image is None:
        raise ValueError

    kernel = np.array([[-1,-1,-1],
                       [-1,9,-1],
                       [-1,-1,-1]])

    shapened_image = cv2.filter2D(image,-1,kernel)

    cv2.imwrite(output_path,shapened_image)

laplacian_shapening('secret_sister.bmp','secret_sister_processed.bmp')
