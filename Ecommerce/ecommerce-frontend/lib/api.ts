import axios from "axios";

export const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE ?? "";

const api = axios.create({
  baseURL: apiBaseUrl,
  headers: {
    "Content-Type": "application/json"
  }
});

api.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const token = window.localStorage.getItem("ec_token");
    if (token) {
      config.headers = config.headers ?? {};
      (config.headers as Record<string, string>).Authorization = "Bearer " + token;
    }
  }
  return config;
});

export default api;
