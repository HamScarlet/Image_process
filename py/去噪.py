import cv2
import numpy as np

def add_noise(img:np.matrix):
    row,col,ch = img.shape
    mean = 0
    sigma = 36
    gauss = np.random.normal(mean,sigma,(row,col,ch))
    gauss = gauss.reshape(row,col,ch)
    noise = gauss + img
    noise = np.clip(noise,0,255).astype(np.uint8)
    return noise


def gauss_filter(img:np.matrix):
    return cv2.GaussianBlur(img,(7,7),0)

if __name__ == "__main__":
    img = cv2.imread("secret_sister.bmp")
    noise_img = add_noise(img)
    cv2.imshow('噪声'.encode("gbk"),noise_img)
    gauss_img = gauss_filter(noise_img)
    cv2.imshow('去噪'.encode("gbk"),gauss_img)
    cv2.imshow('原图'.encode("gbk"),img)
    cv2.waitKey(0)
    cv2.destroyAllWindows()